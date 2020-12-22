import { LightningElement, api } from 'lwc';

export default class TimelineItemDetail extends LightningElement
{
    @api contentDetails;
    @api typeOfContent;
    @api columns;

    get isLayout()
    {
        return this.typeOfContent.toLowerCase() == 'layout+text';
    }

    get size()
    {
        return 12 / this.columns;
    }
}