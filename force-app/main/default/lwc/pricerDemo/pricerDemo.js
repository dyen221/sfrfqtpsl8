import { LightningElement } from 'lwc';
import generateTargetPrice from '@salesforce/apex/TargetPricingService.generateTargetPrice';

export default class PricerDemo extends LightningElement {
    targetPrice;
    message;
    isLoading = false;

    async handleClick() {
        this.isLoading = true;
        this.message = '';
        this.targetPrice = null;

        try {
            const price = await generateTargetPrice();

            this.targetPrice = price;
            this.message = 'Target price generated successfully!';
        } catch (error) {
            this.message = 'Error generating target price.';
            console.error(error);
        } finally {
            this.isLoading = false;
        }
    }
}