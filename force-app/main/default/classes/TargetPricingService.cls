public with sharing class TargetPricingService {

    @AuraEnabled
    public static Decimal generateTargetPrice(
        String accountName,
        String productCode,
        Integer quantity,
        String region,
        String modality
    ) {

        Decimal basePrice = 100.00;

        Decimal targetPrice = basePrice * 1.255;

        return targetPrice.setScale(2);
    }
}