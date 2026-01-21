import { LightningElement, api } from 'lwc';
import promotionStateManager from 'c/promotionStateManager';

export default class PromotionWizardStep1 extends LightningElement {
    
    stateManager = promotionStateManager;
    promotionName;

    connectedCallback(){
        this.promotionName = this.stateManager.getState().promotionName;
    }

    handleChange(event) {
        this.promotionName = event.detail.value;
    }

    @api
    allValid(){
        if(this.promotionName === undefined || this.promotionName === ''){
            return false;
        }
        
        this.stateManager.updatePromotionName(this.promotionName);
        
        return true;
    }
}