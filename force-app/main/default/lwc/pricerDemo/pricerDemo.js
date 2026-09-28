import { LightningElement } from 'lwc';
import generateTargetPrice from '@salesforce/apex/TargetPricingService.generateTargetPrice';

export default class PricerDemo extends LightningElement {

    accountName = 'Global Tech';
    productCode = 'P50C425S27';
    quantity = 10;
    region = 'North America';
    modality = 'Standard';

    targetPrice;
    confidence;
    status;
    message;
    isLoading = false;

    handleInputChange(event) {
        const field = event.target.name;
        this[field] = event.target.value;
    }

    get regionOptions() {
        return [
            { label: 'North America', value: 'North America' },
            { label: 'Europe', value: 'Europe' },
            { label: 'Asia Pacific', value: 'Asia Pacific' },
            { label: 'Middle East', value: 'Middle East' }
        ];
    }

    get modalityOptions() {
        return [
            { label: 'Standard', value: 'Standard' },
            { label: 'Premium', value: 'Premium' },
            { label: 'Enterprise', value: 'Enterprise' }
        ];
    }

    async handleGenerate() {
        this.isLoading = true;

        this.targetPrice = null;
        this.confidence = null;
        this.status = null;
        this.message = '';

        try {
            const price = await generateTargetPrice({
                accountName: this.accountName,
                productCode: this.productCode,
                quantity: Number(this.quantity),
                region: this.region,
                modality: this.modality
            });

            this.targetPrice = price;
            this.confidence = 92;
            this.status = 'Generated';
            this.message = 'Target price generated successfully!';

        } catch (error) {

            console.error(error);

            this.message =
                error?.body?.message ||
                'Error generating target price.';

        } finally {
            this.isLoading = false;
        }
    }
}