/*
BSD 3-Clause License

Copyright (c) 2020, Kshitij Lawate
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its
   contributors may be used to endorse or promote products derived from
   this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/
import { LightningElement, api, wire, track } from 'lwc';
import getSobjectHistory from '@salesforce/apex/TimelineComponentHelper.getSobjectHistory';
import { refreshApex } from '@salesforce/apex';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent'
import tc_noHistoryDataMessage from '@salesforce/label/c.tc_noHistoryDataMessage';

export default class HistoryTimeline extends NavigationMixin(LightningElement)
{
    @api recordId;
    @api objectApiName;
    @api historyTrackedObjectAPIName;
    @api historyObjectAPIName;
    @api relationshipFieldAPI;
    @api firstLevelGrouping;
    @api showTableFormatButton;
    @api componentTitle;

    historyTrackedRecordId;
    displayMessage = tc_noHistoryDataMessage;
    @track listOfValues = [];
    _listOfValues = [];
    _wiredData;
    @api timelineHeight;
    @api flexipageRegionWidth;
    @track showSpinner = true;

    get timelineHeightStyle()
    {
        return 'height:' + this.timelineHeight + ';';
    }

    get contentColumns()
    {
        return this.flexipageRegionWidth == 'SMALL' ? 1 : 2;
    }

    get isSmallRegionWidth()
    {
        return this.flexipageRegionWidth == 'SMALL';
    }

    //defines if to show no data message on UI
    get showDesertIllustration()
    {
        return this.listOfValues.length > 0
    }

    //object for filters to be applied from UI
    @track filters = {
        queryTermFilter: false, queryTerm: ''
    };

    //fetching objet history records 
    @wire(getSobjectHistory, {
        recordId: '$recordId', objectInContext: '$objectApiName', relationshipFieldAPIName: '$relationshipFieldAPI',
        historyTrackedObjectAPIName: '$historyTrackedObjectAPIName', historyObjectAPIName: '$historyObjectAPIName',
        firstLevelGrouping: '$firstLevelGrouping'
    })
    getHistory(result)
    {
        this._wiredData = result;
        console.log('result=', result);
        if (result.error) 
        {
            //console.log(result.error);
            this.showErrorMessage(result.error);
            this.showSpinner = false;
        }
        if (result.data)
        {
            this.historyTrackedRecordId = result.data.historyTrackedRecordId;
            if (result.data.displayMessage)
            {
                this.displayMessage = result.data.displayMessage;
            }

            this._listOfValues = JSON.parse(JSON.stringify(result.data.lstSectionWrapper)); //deep cloning the response from apex 
            this._listOfValues.forEach(sectionItem =>
            {
                if (sectionItem.lstSubSections)
                {
                    sectionItem.lstSubSections.forEach(subSectionItem =>
                    {
                        subSectionItem.showRelativeDateTime = false;
                        //checking if the template contains RELATIVE_DATETIME for replacing the text with Relative date time value 
                        if (subSectionItem && subSectionItem.subSectionTitle && subSectionItem.subSectionTitle.includes('(RELATIVE_DATETIME)'))
                        {
                            subSectionItem.relativeDateTime = new Date(subSectionItem.actualDateTime); //create JS Date object for relative date time 
                            subSectionItem.subSectionTitle = subSectionItem.subSectionTitle.replace('(RELATIVE_DATETIME)', '');
                            subSectionItem.showRelativeDateTime = true
                        }
                        subSectionItem.recordSize = subSectionItem.lstContentString.length;
                    })
                }
                sectionItem.recordSize = sectionItem.lstSubSections.length;
                if (sectionItem.isDateTime)
                {
                    sectionItem.relativeSectionTitle = new Date(sectionItem.sectionTitle);
                }
            });

            this.listOfValues = this._listOfValues;
            this.showSpinner = false;
        }

    }

    //method invoked when text is added to search field 
    handleSearch(event)
    {
        this.filters.queryTerm = event.target.value;
        this.handleSearchHelper();
    }

    //helper method for searching within data in timeline view
    handleSearchHelper()
    {
        //start search only if query term entered is greater than 2 characters. 
        if (this.filters.queryTerm && this.filters.queryTerm.length > 2)
        {
            this.listOfValues = [];
            this.filters.queryTermFilter = true;

            //searching through search tags to find results and add them to listOfvalues property to show on UI
            this._listOfValues.forEach(sectionItem =>
            {
                const showSection = sectionItem.searchTags.indexOf(this.filters.queryTerm.toLowerCase()) > -1;

                const subSectionsFiltered = [];
                sectionItem.lstSubSections.forEach(subSectionItem =>
                {
                    //filtering lowest level content 
                    const contentItemsFiltered = subSectionItem.lstContentString.filter(function (contentItem)
                    {
                        if (contentItem.searchTags.indexOf(this.filters.queryTerm.toLowerCase()) > -1)
                        {
                            return true;
                        }
                        return false;
                    }, this);

                    if (contentItemsFiltered.length > 0)
                    {
                        let subSectionItemCloned = Object.create(subSectionItem);
                        subSectionItemCloned.lstContentString = contentItemsFiltered;
                        subSectionItemCloned.recordSize = subSectionItemCloned.lstContentString.length;
                        subSectionsFiltered.push(subSectionItemCloned);
                    }
                })

                if (subSectionsFiltered.length > 0 || showSection)
                {
                    let sectionItemCloned = Object.create(sectionItem);
                    sectionItemCloned.lstSubSections = subSectionsFiltered;
                    sectionItemCloned.recordSize = sectionItemCloned.lstSubSections.length;
                    this.listOfValues.push(sectionItemCloned);
                }
            });
        }
        else
        {
            this.listOfValues = this._listOfValues;
            this.filters.queryTermFilter = false;
        }
    }
    //method to refresh data from server ***TODO handle loading screen
    refreshData()
    {
        console.log('refreshing data');
        this.showSpinner = true;
        return refreshApex(this._wiredData)
            .then(() =>
            {
                this.showSpinner = false;
            })
            .catch((exp) =>
            {
                this.showErrorMessage(exp);
                this.showSpinner = false;
            });
    }


    //method invoked when expand all button is clicked to expand all subsections 
    handleAllSubSectionExpand()
    {
        this.template.querySelectorAll('[data-ssexpanded="false"]').forEach(element =>
        {
            element.dataset.ssexpanded = "true";
            element.classList.add('slds-is-open');

            let elementId = element.dataset.id;
            let theObj = this.template.querySelector(`lightning-button-icon[data-id="${ elementId }"]`);
            theObj.iconName = 'utility:switch';
        });
    }
    //method invoked when collapse all button is clicked to expand all subsections 
    handleAllSubSectionCollapse()
    {
        this.template.querySelectorAll('[data-ssexpanded="true"]').forEach(element =>
        {
            element.dataset.ssexpanded = "false";
            element.classList.remove('slds-is-open');

            let elementId = element.dataset.id;

            let theObj = this.template.querySelector(`lightning-button-icon[data-id="${ elementId }"]`);
            theObj.iconName = 'utility:chevronright';
        });
    }
    //helper method to handle toggling of sections and sub sections 
    sectionToggleHelper(event, level)
    {
        let currentId = event.target.dataset.id;
        var divblock = this.template.querySelector(`[data-id="${ currentId }"]`);
        if (divblock)
        {
            if ((divblock.dataset.expanded && divblock.dataset.expanded == "true") ||
                (level && level == 'subSection' && divblock.dataset.ssexpanded && divblock.dataset.ssexpanded == "true"))
            {
                divblock.classList.remove('slds-is-open');

                if (level && level == 'subSection')
                {
                    event.target.iconName = 'utility:chevronright';
                    divblock.dataset.ssexpanded = "false";
                }
                else
                {
                    divblock.dataset.expanded = "false";
                }
            }
            else
            {
                divblock.classList.add('slds-is-open');
                if (level && level == 'subSection')
                {
                    event.target.iconName = 'utility:switch';
                    divblock.dataset.ssexpanded = "true";
                }
                else
                {
                    divblock.dataset.expanded = "true";
                }
            }
        }
    }
    //method invoked when a specific section is clicked for expand or collapse. 
    handleSectionToggle(event)
    {
        this.sectionToggleHelper(event, '');
    }
    //method invoked when a specific sub-section is clicked for expand or collapse. 
    handleSubSectionToggle(event)
    {
        this.sectionToggleHelper(event, 'subSection');
    }
    //method involed when "View in table format" button is clicked. 
    handleTableRedirect(event)
    {
        let historyRelatedListPageReference =
        {
            type: 'standard__recordRelationshipPage',
            attributes: {
                "recordId": this.historyTrackedRecordId,
                "objectApiName": this.historyTrackedObjectAPIName,
                "relationshipApiName": 'Histories',
                "actionName": "view"
            }
        };
        event.preventDefault();
        event.stopPropagation();

        this[NavigationMixin.Navigate](historyRelatedListPageReference);
    }

    showErrorMessage(exception)
    {
        if (exception && exception.body && exception.body.message)
        {
            this.showToastMessage('ERROR', exception.body.message, 'error');
        }
        else
        {
            this.showToastMessage('ERROR', 'An error occurred while fetching the data.', 'error');
        }
    }

    showToastMessage(title, messageToDisplay, variant)
    {
        const event = new ShowToastEvent({
            title: title,
            message: messageToDisplay,
            variant: variant
        });
        this.dispatchEvent(event);
    }
}