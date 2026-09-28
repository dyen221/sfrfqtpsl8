import { LightningElement } from 'lwc';

import getQuotes
    from '@salesforce/apex/TargetPricingController.getQuotes';

import getQuoteLines
    from '@salesforce/apex/TargetPricingController.getQuoteLines';

import generateBatchTargetPrices
    from '@salesforce/apex/TargetPricingController.generateBatchTargetPrices';

import approveQuoteLines
    from '@salesforce/apex/TargetPricingController.approveQuoteLines';

import rejectQuoteLines
    from '@salesforce/apex/TargetPricingController.rejectQuoteLines';


export default class PricerDemo extends LightningElement {

    // -----------------------------
    // Screen state
    // -----------------------------

    selectedMode = 'single';

    // -----------------------------
    // Single pricing
    // -----------------------------

    accountName = 'Global Tech';
    productCode = 'P50C425S27';
    quantity = 10;
    region = 'North America';
    modality = 'Standard';
    listPrice = 140;

    targetPrice;
    confidence;
    status;
    message;

    isLoading = false;


    // -----------------------------
    // Batch pricing
    // -----------------------------

    quotes = [];
    quoteLines = [];

    selectedQuoteId;
    selectedQuoteLineIds = new Set();

    isLoadingQuotes = false;
    isLoadingQuoteLines = false;


    // -----------------------------
    // Mode
    // -----------------------------

    get isSingleMode() {
        return this.selectedMode === 'single';
    }

    get isBatchMode() {
        return this.selectedMode === 'batch';
    }


    handleSingleMode() {

        this.selectedMode = 'single';

        this.clearResult();
    }


    handleBatchMode() {

        this.selectedMode = 'batch';

        this.clearResult();

        this.loadQuotes();
    }


    // -----------------------------
    // Button styles
    // -----------------------------

    get singleButtonVariant() {

        return this.isSingleMode
            ? 'brand'
            : 'neutral';
    }


    get batchButtonVariant() {

        return this.isBatchMode
            ? 'brand'
            : 'neutral';
    }

    get isSingleGenerated() {
        return this.isSingleMode && this.status === 'Generated';
    }

    handleSingleApprove() {
        if (this.status !== 'Generated') {
            return;
        }

        this.status = 'Approved';
        this.message = 'Target price approved successfully!';
    }

    handleSingleReject() {
        if (this.status !== 'Generated') {
            return;
        }

        this.status = 'Rejected';
        this.message = 'Target price rejected.';
    }


    // -----------------------------
    // Single input handling
    // -----------------------------

    handleInputChange(event) {

        const field = event.target.name;

        this[field] = event.target.value;
    }


    // -----------------------------
    // Dropdowns
    // -----------------------------

    get regionOptions() {

        return [
            {
                label: 'North America',
                value: 'North America'
            },
            {
                label: 'Europe',
                value: 'Europe'
            },
            {
                label: 'Asia Pacific',
                value: 'Asia Pacific'
            },
            {
                label: 'Middle East',
                value: 'Middle East'
            }
        ];
    }


    get modalityOptions() {

        return [
            {
                label: 'Standard',
                value: 'Standard'
            },
            {
                label: 'Premium',
                value: 'Premium'
            },
            {
                label: 'Enterprise',
                value: 'Enterprise'
            }
        ];
    }


    get quoteOptions() {

        return this.quotes.map(quote => {

            return {
                label: `${quote.Name} - ${quote.SBQQ__Account__r?.Name || 'No Account'}`,
                value: quote.Id
            };

        });
    }


    // -----------------------------
    // Single pricing
    // -----------------------------

    handleGenerate() {

        this.isLoading = true;

        this.clearResult();

        // Temporary pricing engine.
        // We will replace this with the real
        // Apex pricing logic next.

        setTimeout(() => {

            this.targetPrice =
                Number(this.listPrice) * 0.8964;

            this.targetPrice =
                Number(this.targetPrice.toFixed(2));

            this.confidence = 92;

            this.status = 'Generated';

            this.message =
                'Target price generated successfully!';

            this.isLoading = false;

        }, 700);
    }


    // -----------------------------
    // Load Quotes
    // -----------------------------

    async loadQuotes() {

        this.isLoadingQuotes = true;

        this.message = '';

        try {

            this.quotes = await getQuotes();

        } catch (error) {

            console.error(error);

            this.message =
                error?.body?.message ||
                'Unable to load Salesforce Quotes.';

        } finally {

            this.isLoadingQuotes = false;
        }
    }


    // -----------------------------
    // Quote selected
    // -----------------------------

    handleRowSelection(event) {

        const lineId = event.target.dataset.id;

        if (event.target.checked) {
            this.selectedQuoteLineIds.add(lineId);
        } else {
            this.selectedQuoteLineIds.delete(lineId);
        }

        this.selectedQuoteLineIds =
            new Set(this.selectedQuoteLineIds);
    }


    async handleQuoteChange(event) {

        this.selectedQuoteId =
            event.detail.value;

        this.quoteLines = [];
        this.selectedQuoteLineIds = new Set();

        if (!this.selectedQuoteId) {
            return;
        }

        await this.loadQuoteLines();
    }


    // -----------------------------
    // Load Quote Lines
    // -----------------------------

    async loadQuoteLines() {

        this.isLoadingQuoteLines = true;

        try {

            this.quoteLines =
                await getQuoteLines({
                    quoteId: this.selectedQuoteId
                });

            return this.quoteLines;

        } catch (error) {

            console.error(error);

            this.message =
                error?.body?.message ||
                'Unable to load Quote Lines.';

            return [];

        } finally {

            this.isLoadingQuoteLines = false;
        }
    }


    // -----------------------------
    // Batch Generate
    // -----------------------------

    async handleBatchGenerate() {

        if (!this.selectedQuoteId) {

            this.message =
                'Please select a Quote first.';

            return;
        }

        if (!this.quoteLines.length) {

            this.message =
                'No Quote Lines found for this Quote.';

            return;
        }

        this.isLoadingQuoteLines = true;

        this.message = 'Generating batch target prices...';

        try {

            this.quoteLines =
                await generateBatchTargetPrices({
                    quoteId: this.selectedQuoteId
                });

            this.message =
                `${this.quoteLines.length} Quote Line(s) processed successfully.`;

        } catch (error) {

            console.error(error);

            this.message =
                error?.body?.message ||
                'Unable to generate batch target pricing.';

        } finally {

            this.isLoadingQuoteLines = false;
        }
    }


    async handleApproveSelected() {

        const selectedIds =
            Array.from(this.selectedQuoteLineIds);

        if (!selectedIds.length) {
            this.message =
                'Please select at least one Quote Line.';
            return;
        }

        this.isLoadingQuoteLines = true;
        this.message = 'Approving selected Quote Lines...';

        try {

            await approveQuoteLines({
                quoteLineIds: selectedIds
            });

            this.quoteLines = this.quoteLines.map(line => {

                if (
                    selectedIds.includes(line.Id) &&
                    line.TP_Status__c === 'Generated'
                ) {
                    return {
                        ...line,
                        TP_Status__c: 'Approved'
                    };
                }

                return line;
            });

            this.selectedQuoteLineIds = new Set();

            this.message =
                `${selectedIds.length} Quote Line(s) approved successfully.`;

        } catch (error) {

            console.error(
                'APPROVE ERROR:',
                JSON.stringify(error)
            );

            let errorMessage =
                'Unable to approve Quote Lines.';

            if (error?.body?.message) {

                errorMessage =
                    error.body.message;

            } else if (
                error?.body?.pageErrors?.length
            ) {

                errorMessage =
                    error.body.pageErrors[0].message;

            } else if (
                error?.body?.fieldErrors
            ) {

                errorMessage =
                    JSON.stringify(
                        error.body.fieldErrors
                    );
            }

            this.message =
                'Approve failed: ' + errorMessage;

        } finally {

            this.isLoadingQuoteLines = false;
        }
    }


    async handleRejectSelected() {

        const selectedIds =
            Array.from(this.selectedQuoteLineIds);

        if (!selectedIds.length) {
            this.message =
                'Please select at least one Quote Line.';
            return;
        }

        this.isLoadingQuoteLines = true;
        this.message = 'Rejecting selected Quote Lines...';

        try {

            await rejectQuoteLines({
                quoteLineIds: selectedIds
            });

            this.quoteLines = this.quoteLines.map(line => {

                if (
                    selectedIds.includes(line.Id) &&
                    line.TP_Status__c === 'Generated'
                ) {
                    return {
                        ...line,
                        TP_Status__c: 'Rejected'
                    };
                }

                return line;
            });

            this.selectedQuoteLineIds = new Set();

            this.message =
                `${selectedIds.length} Quote Line(s) rejected successfully.`;

        } catch (error) {

            console.error(
                'REJECT ERROR:',
                JSON.stringify(error)
            );

            let errorMessage =
                'Unable to reject Quote Lines.';

            if (error?.body?.message) {

                errorMessage =
                    error.body.message;

            } else if (
                error?.body?.pageErrors?.length
            ) {

                errorMessage =
                    error.body.pageErrors[0].message;

            } else if (
                error?.body?.fieldErrors
            ) {

                errorMessage =
                    JSON.stringify(
                        error.body.fieldErrors
                    );
            }

            this.message =
                'Reject failed: ' + errorMessage;

        } finally {

            this.isLoadingQuoteLines = false;
        }
    }


    // -----------------------------
    // Clear result
    // -----------------------------

    clearResult() {

        this.targetPrice = null;

        this.confidence = null;

        this.status = null;

        this.message = '';
    }
}