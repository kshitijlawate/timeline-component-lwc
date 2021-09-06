/*
    BSD 3 - Clause License
Copyright(c) 2020, Kshitij Lawate(kshitijlawate.com)

All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
1. Redistributions of source code must retain the above copyright notice, this
list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright notice,
    this list of conditions and the following disclaimer in the documentation
and / or other materials provided with the distribution.
3. Neither the name of the copyright holder nor the names of its
contributors may be used to endorse or promote products derived from
this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED.IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
    OR TORT(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/
import { LightningElement, api, wire, track } from 'lwc';
import getSobjectHistory from '@salesforce/apex/TimelineComponentHelper.getSobjectHistory';
import { refreshApex } from '@salesforce/apex';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent'
import lblMsgError_NoHistoryData from '@salesforce/label/c.MsgError_NoHistoryData';
import lblMsgError_Generic from '@salesforce/label/c.MsgError_Generic';

export default class HistoryTimeline extends NavigationMixin(LightningElement)
{
    @api recordId; //Id of the Record in context 
    @api relationshipFieldAPI; //API name of the relationship field which determines Record for which history to be shown
    @api componentTitle; //Title of the component 
    @api timelineConfigName; //Name of the timeline config record created in custom Timeline COnfiguration object 
    @api flexipageRegionWidth;
    @track showSpinner = true;

    //Timeline configuration properties 
    showTableFormatButton; //defines if additional button should be shown that navigates to OOB history related list in table format 
    showRecordLink; //Defines if the record link button should be shown 
    selectedDateFilterValue; //value of the selected date filter 
    selectedDateFilterLabel; //label of the selected date filter 
    showDateFilter = false;
    @api timelineHeight;
    @track calendarFilter = [];

    //Properties evaluated in Apex 
    historyTrackedRecordId; //Id of the Record for which history to be shown. This is evaluated based on relationshipFieldAPI
    @track listOfValues = [];
    _listOfValues = [];
    _wiredData;
    _mapDateFilters = {};

    displayMessage = lblMsgError_NoHistoryData;
    @track paramWrapper;

    //object for filters to be applied from UI
    @track filters = {
        queryTermFilter: false, queryTerm: ''
    };

    get timelineHeightStyle() {
        return (this.timelineHeight ? 'max-height:' + this.timelineHeight + ';' : '');
    }

    get contentColumns() {
        return this.flexipageRegionWidth == 'SMALL' ? 1 : 2;
    }

    get isSmallRegionWidth() {
        return this.flexipageRegionWidth == 'SMALL';
    }

    get showFilterInfo() {
        return this.showDateFilter;
    }

    //defines if to show no data message on UI
    get showDesertIllustration() {
        return this.listOfValues.length <= 0;
    }

    connectedCallback() {
        if (!this.timelineConfigName) {
            this.timelineConfigName = 'default';
        }
        this.paramWrapper = {
            recordId: this.recordId, timelineConfigName: this.timelineConfigName, relationshipFieldAPI: this.relationshipFieldAPI, filters: {}
        };
    }

    //fetching objet history records 
    @wire(getSobjectHistory, { paramWrapper: '$paramWrapper' })
    getHistory(result) {
        this._wiredData = result;
        if (result.error) {
            this.showErrorMessage(result.error);
            this.showSpinner = false;
        }
        if (result.data) {
            this.historyTrackedRecordId = result.data.historyTrackedRecordId;
            if (result.data.displayMessage) {
                this.displayMessage = result.data.displayMessage;
            }

            this._listOfValues = JSON.parse(JSON.stringify(result.data.lstSectionWrapper)); //deep cloning the response from apex 
            this._listOfValues.forEach(sectionItem => {
                if (sectionItem.lstSubSections) {
                    sectionItem.lstSubSections.forEach(subSectionItem => {
                        subSectionItem.showRelativeDateTime = false;
                        //checking if the template contains RELATIVE_DATETIME for replacing the text with Relative date time value 
                        if (subSectionItem && subSectionItem.subSectionTitle && subSectionItem.subSectionTitle.includes('(RELATIVE_DATETIME)')) {
                            subSectionItem.relativeDateTime = new Date(subSectionItem.actualDateTime); //create JS Date object for relative date time 
                            subSectionItem.subSectionTitle = subSectionItem.subSectionTitle.replace('(RELATIVE_DATETIME)', '');
                            subSectionItem.showRelativeDateTime = true
                        }
                        subSectionItem.recordSize = subSectionItem.lstContentString.length;
                    })
                }
                sectionItem.recordSize = sectionItem.lstSubSections.length;
                if (sectionItem.isDateTime) {
                    sectionItem.relativeSectionTitle = new Date(sectionItem.sectionTitle);
                }
            });

            this.showDateFilter = result.data.showDateFilter;

            if (this.calendarFilter.length == 0 && result.data.showDateFilter) {
                this.selectedDateFilterValue = result.data.selectedDateFilter;
                result.data.lstDateFilters.forEach(dateFilterJS => {
                    const dateFilterObj = {
                        id: dateFilterJS.keyValue, label: dateFilterJS.optionLabel, value: dateFilterJS.optionValue
                    }

                    this._mapDateFilters[dateFilterJS.optionValue] = dateFilterJS.optionLabel;

                    dateFilterObj.checked = dateFilterJS.optionValue == this.selectedDateFilterValue ? true : false;
                    if (dateFilterJS.optionValue == this.selectedDateFilterValue) {
                        this.selectedDateFilterLabel = dateFilterJS.optionLabel;
                    }
                    this.calendarFilter.push(dateFilterObj);
                });
            }

            this.listOfValues = this._listOfValues;
            this.showTableFormatButton = result.data.showTableFormatButton;
            this.showRecordLink = result.data.showRecordLink;
            this.timelineHeight = result.data.timelineHeight;
            this.showSpinner = false;
        }
    }

    //method invoked when text is added to search field 
    handleSearch(event) {
        this.filters.queryTerm = encodeURIComponent(event.target.value);
        this.handleSearchHelper();
    }

    //helper method for searching within data in timeline view
    handleSearchHelper() {
        //start search only if query term entered is greater than 2 characters. 
        if (this.filters.queryTerm && this.filters.queryTerm.length > 2) {
            this.listOfValues = [];
            this.filters.queryTermFilter = true;

            //searching through search tags to find results and add them to listOfvalues property to show on UI
            this._listOfValues.forEach(sectionItem => {
                const showSection = sectionItem.searchTags.indexOf(this.filters.queryTerm.toLowerCase()) > -1;
                const subSectionsFiltered = [];
                sectionItem.lstSubSections.forEach(subSectionItem => {
                    //filtering lowest level content 
                    const contentItemsFiltered = subSectionItem.lstContentString.filter(function (contentItem) {
                        if (contentItem.searchTags.indexOf(this.filters.queryTerm.toLowerCase()) > -1) {
                            return true;
                        }
                        return false;
                    }, this);

                    if (contentItemsFiltered.length > 0) {
                        let subSectionItemCloned = Object.create(subSectionItem);
                        subSectionItemCloned.lstContentString = contentItemsFiltered;
                        subSectionItemCloned.recordSize = subSectionItemCloned.lstContentString.length;
                        subSectionsFiltered.push(subSectionItemCloned);
                    }
                })

                if (subSectionsFiltered.length > 0 || showSection) {
                    let sectionItemCloned = Object.create(sectionItem);
                    sectionItemCloned.lstSubSections = subSectionsFiltered;
                    sectionItemCloned.recordSize = sectionItemCloned.lstSubSections.length;
                    this.listOfValues.push(sectionItemCloned);
                }
            });
        }
        else {
            this.listOfValues = this._listOfValues;
            this.filters.queryTermFilter = false;
        }
    }
    //method to refresh data from server ***TODO handle loading screen
    refreshData() {
        this.showSpinner = true;
        return refreshApex(this._wiredData)
            .then(() => {
                this.showSpinner = false;
            })
            .catch((exp) => {
                this.showErrorMessage(exp);
                this.showSpinner = false;
            });
    }

    handleOnselect(event) {
        try {
            this.showSpinner = true;

            const selectedItemValue = event.detail.value;
            this.selectedDateFilterValue = selectedItemValue;

            for (let menuItem of this.calendarFilter) {
                menuItem.checked = menuItem.value === selectedItemValue ? true : false;
            }

            if (this._mapDateFilters[this.selectedDateFilterValue]) {
                this.selectedDateFilterLabel = this._mapDateFilters[this.selectedDateFilterValue];
            }
            this.paramWrapper = {
                ...this.paramWrapper, filters: {
                    ...this.paramWrapper.filters, dateFilter: this.selectedDateFilterValue
                }
            }
        }
        catch (ex) {
            console.log(ex);
            this.showErrorMessage(ex);
        }
    }

    //method invoked when expand all button is clicked to expand all subsections 
    handleAllSubSectionExpand() {
        this.template.querySelectorAll('[data-ssexpanded="false"]').forEach(element => {
            element.dataset.ssexpanded = "true";
            element.classList.add('slds-is-open');

            let elementId = element.dataset.id;
            let theObj = this.template.querySelector(`lightning-button-icon[data-id="${elementId}"]`);
            theObj.iconName = 'utility:switch';
        });
    }
    //method invoked when collapse all button is clicked to expand all subsections 
    handleAllSubSectionCollapse() {
        this.template.querySelectorAll('[data-ssexpanded="true"]').forEach(element => {
            element.dataset.ssexpanded = "false";
            element.classList.remove('slds-is-open');

            let elementId = element.dataset.id;

            let theObj = this.template.querySelector(`lightning-button-icon[data-id="${elementId}"]`);
            theObj.iconName = 'utility:chevronright';
        });
    }
    //helper method to handle toggling of sections and sub sections 
    sectionToggleHelper(event, level) {
        let currentId = event.target.dataset.id;
        var divblock = this.template.querySelector(`[data-id="${currentId}"]`);
        if (divblock) {
            if ((divblock.dataset.expanded && divblock.dataset.expanded == "true") || (level && level == 'subSection' && divblock.dataset.ssexpanded && divblock.dataset.ssexpanded == "true")) {
                divblock.classList.remove('slds-is-open');

                if (level && level == 'subSection') {
                    event.target.iconName = 'utility:chevronright';
                    divblock.dataset.ssexpanded = "false";
                }
                else {
                    divblock.dataset.expanded = "false";
                }
            }
            else {
                divblock.classList.add('slds-is-open');
                if (level && level == 'subSection') {
                    event.target.iconName = 'utility:switch';
                    divblock.dataset.ssexpanded = "true";
                }
                else {
                    divblock.dataset.expanded = "true";
                }
            }
        }
    }
    //method invoked when a specific section is clicked for expand or collapse. 
    handleSectionToggle(event) {
        this.sectionToggleHelper(event, '');
    }
    //method invoked when a specific sub-section is clicked for expand or collapse. 
    handleSubSectionToggle(event) {
        this.sectionToggleHelper(event, 'subSection');
    }

    //method involed when "View in table format" button is clicked. 
    handleTableRedirect(event) {
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

    //method invoked when "Navigate to record detail" button is clicked. 
    handleRecordDetailsRedirect(event) {
        let recordDetailPageReference =
        {
            type: 'standard__recordPage',
            attributes: {
                "recordId": this.historyTrackedRecordId,
                "objectApiName": this.historyTrackedObjectAPIName,
                "actionName": "view"
            }
        };
        event.preventDefault();
        event.stopPropagation();

        this[NavigationMixin.Navigate](recordDetailPageReference);
    }



    showErrorMessage(exception) {
        if (exception && exception.body && exception.body.message) {
            this.showToastMessage('ERROR', exception.body.message, 'error');
            this.displayMessage = exception.body.message;
        }
        else {
            this.showToastMessage('ERROR', lblMsgError_Generic, 'error');
            this.displayMessage = lblMsgError_Generic;
        }
    }

    showToastMessage(title, messageToDisplay, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: messageToDisplay,
            variant: variant
        });
        this.dispatchEvent(event);
    }
}