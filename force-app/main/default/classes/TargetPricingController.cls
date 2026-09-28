public with sharing class TargetPricingController {

    // ============================================
    // GET QUOTES
    // ============================================

    @AuraEnabled(cacheable=true)
    public static List<SBQQ__Quote__c> getQuotes() {

        return [
            SELECT
                Id,
                Name,
                SBQQ__Account__c,
                SBQQ__Account__r.Name
            FROM SBQQ__Quote__c
            ORDER BY CreatedDate DESC
            LIMIT 50
        ];
    }


    // ============================================
    // GET QUOTE LINES
    // ============================================

    @AuraEnabled(cacheable=true)
    public static List<SBQQ__QuoteLine__c> getQuoteLines(
        Id quoteId
    ) {

        if (quoteId == null) {
            return new List<SBQQ__QuoteLine__c>();
        }

        return [
            SELECT
                Id,
                Name,
                SBQQ__Product__c,
                SBQQ__Product__r.Name,
                SBQQ__Product__r.ProductCode,
                SBQQ__Quantity__c,
                SBQQ__ListPrice__c,
                Target_Price__c,
                TP_Confidence__c,
                TP_Status__c
            FROM SBQQ__QuoteLine__c
            WHERE SBQQ__Quote__c = :quoteId
            ORDER BY CreatedDate ASC
        ];
    }


    // ============================================
    // GENERATE SINGLE TARGET PRICE
    // ============================================

    @AuraEnabled
    public static Decimal generateSingleTargetPrice(
        Decimal listPrice,
        Decimal quantity
    ) {

        if (listPrice == null || listPrice < 0) {
            throw new AuraHandledException(
                'List Price must be greater than or equal to zero.'
            );
        }

        if (quantity == null || quantity <= 0) {
            throw new AuraHandledException(
                'Quantity must be greater than zero.'
            );
        }

        /*
         * Demo pricing logic.
         *
         * This is intentionally simple for now.
         * Later we can replace this with your
         * actual pricing/model logic.
         */

        Decimal discount = 0.10;

        Decimal targetPrice =
            listPrice * (1 - discount);

        return targetPrice.setScale(2);
    }


    // ============================================
    // GENERATE BATCH TARGET PRICES
    // ============================================

    @AuraEnabled
    public static List<SBQQ__QuoteLine__c> generateBatchTargetPrices(
        Id quoteId
    ) {

        if (quoteId == null) {
            throw new AuraHandledException(
                'Please select a Quote.'
            );
        }


        List<SBQQ__QuoteLine__c> quoteLines = [

            SELECT
                Id,
                Name,
                SBQQ__Product__c,
                SBQQ__Product__r.Name,
                SBQQ__Product__r.ProductCode,
                SBQQ__Quantity__c,
                SBQQ__ListPrice__c,
                Target_Price__c,
                TP_Confidence__c,
                TP_Status__c

            FROM SBQQ__QuoteLine__c

            WHERE SBQQ__Quote__c = :quoteId

            ORDER BY CreatedDate ASC
        ];


        if (quoteLines.isEmpty()) {

            throw new AuraHandledException(
                'No Quote Lines found for this Quote.'
            );
        }


        List<SBQQ__QuoteLine__c> linesToUpdate =
            new List<SBQQ__QuoteLine__c>();


        for (SBQQ__QuoteLine__c line : quoteLines) {

            /*
             * Do not overwrite an already approved
             * pricing decision.
             */

            if (line.TP_Status__c == 'Approved') {
                continue;
            }


            if (
                line.SBQQ__ListPrice__c == null ||
                line.SBQQ__ListPrice__c < 0
            ) {
                continue;
            }


            Decimal targetPrice =
                line.SBQQ__ListPrice__c * 0.90;


            line.Target_Price__c =
                targetPrice.setScale(2);


            /*
             * Demo confidence.
             *
             * Later this will come from the
             * pricing/AI model.
             */

            line.TP_Confidence__c = 92;


            line.TP_Status__c = 'Generated';


            linesToUpdate.add(line);
        }


        if (!linesToUpdate.isEmpty()) {

            update linesToUpdate;
        }


        /*
         * Query again so the LWC receives the
         * latest Salesforce values.
         */

        return [

            SELECT
                Id,
                Name,
                SBQQ__Product__c,
                SBQQ__Product__r.Name,
                SBQQ__Product__r.ProductCode,
                SBQQ__Quantity__c,
                SBQQ__ListPrice__c,
                Target_Price__c,
                TP_Confidence__c,
                TP_Status__c

            FROM SBQQ__QuoteLine__c

            WHERE SBQQ__Quote__c = :quoteId

            ORDER BY CreatedDate ASC
        ];
    }


    @AuraEnabled
    public static List<SBQQ__QuoteLine__c> approveQuoteLines(
        List<Id> quoteLineIds
    ) {
        try {

            if (quoteLineIds == null || quoteLineIds.isEmpty()) {
                throw new AuraHandledException(
                    'Please select at least one Quote Line.'
                );
            }

            System.debug('APPROVE IDS: ' + quoteLineIds);

            List<SBQQ__QuoteLine__c> lines = [
                SELECT
                    Id,
                    Name,
                    SBQQ__Product__c,
                    SBQQ__Product__r.Name,
                    SBQQ__Product__r.ProductCode,
                    SBQQ__Quantity__c,
                    SBQQ__ListPrice__c,
                    Target_Price__c,
                    TP_Confidence__c,
                    TP_Status__c
                FROM SBQQ__QuoteLine__c
                WHERE Id IN :quoteLineIds
            ];

            System.debug('LINES FOUND: ' + lines.size());

            if (lines.isEmpty()) {
                throw new AuraHandledException(
                    'No Quote Lines found for the selected IDs.'
                );
            }

            for (SBQQ__QuoteLine__c line : lines) {

                System.debug(
                    'BEFORE APPROVE: ' +
                    line.Id +
                    ' Status=' +
                    line.TP_Status__c +
                    ' Target=' +
                    line.Target_Price__c
                );

                if (line.TP_Status__c == 'Generated') {
                    line.TP_Status__c = 'Approved';
                }
            }

            update lines;

            System.debug('APPROVE UPDATE SUCCESS');

            return lines;

        } catch (Exception e) {

            System.debug(
                'APPROVE ERROR: ' +
                e.getTypeName() +
                ' - ' +
                e.getMessage()
            );

            System.debug(
                'APPROVE STACK: ' +
                e.getStackTraceString()
            );

            throw new AuraHandledException(
                'Approval failed: ' + e.getMessage()
            );
        }
    }

    @AuraEnabled
    public static List<SBQQ__QuoteLine__c> rejectQuoteLines(
        List<Id> quoteLineIds
    ) {

        if (quoteLineIds == null || quoteLineIds.isEmpty()) {
            throw new AuraHandledException(
                'Please select at least one Quote Line.'
            );
        }

        List<SBQQ__QuoteLine__c> lines = [
            SELECT
                Id,
                Name,
                SBQQ__Product__c,
                SBQQ__Product__r.Name,
                SBQQ__Product__r.ProductCode,
                SBQQ__Quantity__c,
                SBQQ__ListPrice__c,
                Target_Price__c,
                TP_Confidence__c,
                TP_Status__c
            FROM SBQQ__QuoteLine__c
            WHERE Id IN :quoteLineIds
        ];

        for (SBQQ__QuoteLine__c line : lines) {

            if (line.TP_Status__c == 'Generated') {
                line.TP_Status__c = 'Rejected';
            }
        }

        update lines;

        return lines;
    }
}