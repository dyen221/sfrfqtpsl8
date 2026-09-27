public class ChangeEventIngestionQueueable
    implements Queueable, Database.AllowsCallouts {

    // Configure this Named Credential in Setup > Named Credentials,
    // pointing at the API Gateway in front of the Change Event Ingestion API.
    private static final String NAMED_CREDENTIAL = 'callout:Change_Event_Ingestion_API';
    private static final String ENDPOINT_PATH = '/v1/change-events';

    private String entityName;
    private String recordId;
    private String changeType;
    private String eventUuid;
    private String commitUser;
    private Long commitTimestamp;
    private String transactionKey;
    private Long commitNumber;
    private Long replayId;
    private String changeOrigin;
    private List<String> changedFields;
    private Map<String, Object> newValues;

    public ChangeEventIngestionQueueable(
        String entityName,
        String recordId,
        String changeType,
        String eventUuid,
        String commitUser,
        Long commitTimestamp,
        String transactionKey,
        Long commitNumber,
        Long replayId,
        String changeOrigin,
        List<String> changedFields,
        Map<String, Object> newValues
    ) {
        this.entityName = entityName;
        this.recordId = recordId;
        this.changeType = changeType;
        this.eventUuid = eventUuid;
        this.commitUser = commitUser;
        this.commitTimestamp = commitTimestamp;
        this.transactionKey = transactionKey;
        this.commitNumber = commitNumber;
        this.replayId = replayId;
        this.changeOrigin = changeOrigin;
        this.changedFields = changedFields;
        this.newValues = newValues;
    }

    public void execute(QueueableContext context) {
        Map<String, Object> payload = new Map<String, Object>();

        // Dedup / idempotency - event_key = EventUuid, per spec.
        payload.put('eventUuid', eventUuid);
        payload.put('eventKey', eventUuid);

        // Identity
        payload.put('entityName', entityName);
        payload.put('recordId', recordId);
        payload.put('changeType', changeType);
        payload.put('sourceType', 'CHANGE_EVENT'); // vs 'API' for direct calls

        // CDC metadata + watermark
        payload.put('commitUser', commitUser);
        payload.put('commitTimestamp', commitTimestamp);
        payload.put('transactionKey', transactionKey);
        payload.put('commitNumber', commitNumber);
        payload.put('replayId', replayId);
        payload.put('changeOrigin', changeOrigin); // signal for MANUAL_PRICE_OVERRIDE eval

        // Data - CDC only carries NEW values; middleware derives "before"
        // from its own event ledger.
        payload.put('changedFields', changedFields);
        payload.put('newValues', newValues);

        String jsonBody = JSON.serialize(payload);

        System.debug('================================');
        System.debug('CHANGE EVENT INGESTION CALLOUT - ' + entityName);
        System.debug('Event UUID: ' + eventUuid);
        System.debug('Record Id: ' + recordId);
        System.debug('Payload: ' + jsonBody);
        System.debug('================================');

        HttpRequest req = new HttpRequest();
        req.setEndpoint(NAMED_CREDENTIAL + ENDPOINT_PATH);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        // Ingestion API dedups on this header (D... Section 6.4)
        req.setHeader('Idempotency-Key', eventUuid);
        req.setBody(jsonBody);
        req.setTimeout(30000);

        try {
            Http http = new Http();
            HttpResponse res = http.send(req);

            System.debug('INGESTION API RESPONSE: ' + res.getStatusCode() + ' ' + res.getBody());

            if (res.getStatusCode() >= 300) {
                logFailure(jsonBody, 'HTTP ' + res.getStatusCode() + ': ' + res.getBody());
            }
        } catch (Exception e) {
            System.debug('INGESTION CALLOUT FAILED: ' + e.getMessage());
            logFailure(jsonBody, e.getMessage());
        }
    }

    // Persist failed callouts so they're visible to support, not just debug
    // logs. Nightly SL8 reconciliation is the ultimate safety net, but this
    // gives faster visibility into individual failed deliveries.
    private void logFailure(String payloadJson, String errorMessage) {
        try {
            insert new Change_Event_Failure__c(
                Event_Uuid__c = eventUuid,
                Entity_Name__c = entityName,
                Record_Id__c = recordId,
                Payload__c = payloadJson,
                Error_Message__c = errorMessage,
                Replay_Id__c = String.valueOf(replayId)
            );
        } catch (Exception ex) {
            System.debug('FAILED TO LOG CHANGE EVENT FAILURE: ' + ex.getMessage());
        }
    }
}