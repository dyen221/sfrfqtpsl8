public class ChangeEventTriggerHandler {

    private static final Set<String> SYSTEM_FIELDS_TO_SKIP = new Set<String>{
        'ChangeEventHeader'
    };

    public static void handle(String entityName, List<SObject> changeEvents) {
        for (SObject evt : changeEvents) {
            processSingleEvent(entityName, evt);
        }
    }

    private static void processSingleEvent(String entityName, SObject evt) {
        EventBus.ChangeEventHeader header =
            (EventBus.ChangeEventHeader) evt.get('ChangeEventHeader');

        String changeType        = header.getChangeType();
        String commitUser        = header.getCommitUser();
        Long   commitTimestamp   = header.getCommitTimestamp();
        String transactionKey    = header.getTransactionKey();
        Long   commitNumber      = header.getCommitNumber();
        String changeOrigin      = header.getChangeOrigin();
        List<String> changedFlds = header.getChangedFields();
        List<String> recordIds   = header.getRecordIds();

        // Per-object watermark used by the middleware for gap detection.
        Long replayId = EventBus.TriggerContext.newTriggerContext().getReplayId();

        // Salesforce CDC has no native EventUuid - minted here at capture.
        // This value becomes event_key for middleware dedup.
        String eventUuid = Uuid.randomUUID().toString();

        Map<String, Object> populatedFields = evt.getPopulatedFieldsAsMap();

        Map<String, Object> newValues = new Map<String, Object>();
        List<String> flattenedChangedFields = new List<String>();

        Set<String> fieldsToProcess = new Set<String>();
        if (changeType == 'CREATE') {
            // No changedFields on CREATE - the full populated record IS the change.
            fieldsToProcess.addAll(populatedFields.keySet());
            fieldsToProcess.removeAll(SYSTEM_FIELDS_TO_SKIP);
        } else {
            for (String f : changedFlds) {
                // changedFields may include dotted compound paths
                // (e.g. BillingAddress.Country); look up by top-level name.
                fieldsToProcess.add(f.contains('.') ? f.substringBefore('.') : f);
            }
        }

        for (String fieldName : fieldsToProcess) {
            Object rawValue = populatedFields.get(fieldName);
            flattenInto(fieldName, rawValue, newValues, flattenedChangedFields);
        }

        System.debug('================================');
        System.debug('CDC EVENT CAPTURED - ' + entityName);
        System.debug('Event UUID (event_key): ' + eventUuid);
        System.debug('Change Type: ' + changeType);
        System.debug('Change Origin: ' + changeOrigin);
        System.debug('Replay Id (watermark): ' + replayId);
        System.debug('Commit User: ' + commitUser);
        System.debug('Changed Fields: ' + flattenedChangedFields);
        System.debug('================================');

        for (String recordId : recordIds) {
            System.enqueueJob(
                new ChangeEventIngestionQueueable(
                    entityName,
                    recordId,
                    changeType,
                    eventUuid,
                    commitUser,
                    commitTimestamp,
                    transactionKey,
                    commitNumber,
                    replayId,
                    changeOrigin,
                    flattenedChangedFields,
                    newValues
                )
            );
        }
    }

    // Recursively flattens compound field values (Address, Location) into
    // dot-path keys, e.g. BillingAddress -> BillingAddress.Country / .CountryCode.
    private static void flattenInto(
        String prefix,
        Object value,
        Map<String, Object> out,
        List<String> fieldNamesOut
    ) {
        if (value instanceof Address) {
            Map<String, Object> addrMap =
                (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(value));
            for (String key : addrMap.keySet()) {
                String flatName = prefix + '.' + key;
                out.put(flatName, addrMap.get(key));
                fieldNamesOut.add(flatName);
            }
        } else if (value instanceof Location) {
            Location loc = (Location) value;
            out.put(prefix + '.latitude', loc.getLatitude());
            out.put(prefix + '.longitude', loc.getLongitude());
            fieldNamesOut.add(prefix + '.latitude');
            fieldNamesOut.add(prefix + '.longitude');
        } else {
            out.put(prefix, value);
            fieldNamesOut.add(prefix);
        }
    }
}