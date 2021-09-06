/*
BSD 3-Clause License
Copyright (c) 2020, Kshitij Lawate (kshitijlawate.com)

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

*Class Details*
Helper class whose methods are invoked in LWC

*/
public with sharing class TimelineComponentHelper {
    static Map<String, String> lovDateFilters; 
    //map of date filter with field value as Key and its label as value 
    static Map<String, String> mapLOVDateFilters {
        get {
            if(lovDateFilters == null) { 
                lovDateFilters = new Map<String, String> (); 
                for(Schema.PicklistEntry pe : Timeline_Configuration__c.Visible_Date_Filters__c.getDescribe().getPicklistValues()) {
                    if(pe.isActive())   lovDateFilters.put(pe.getValue(), pe.getLabel());
                }
            }
            return lovDateFilters;
        }
    }

    static Map<String, Object> mapLookupFieldToId = new Map<String, Object> (); 
    static String recordCurrencyIsoCode;
    
    @TestVisible
    static List<SObject> lstRecordHistory = new List<Sobject> (); //list of record history records 
    
    //method that is invoked from the LWC to fetch history object data. 
    @AuraEnabled(cacheable=true)
    public static BaseWrapper getSobjectHistory(ParamWrapper paramWrapper) { 
        BaseWrapper twIns = new BaseWrapper();
        try { 
            Timeline_Configuration__c tcIns = new Timeline_Configuration__c();   
            Boolean isTimelineConfigProvided = false;
            // ***VALIDATION*** : making sure parameters passed are not null 
            if(paramWrapper.recordId == null) throw new TimelineComponentException(System.Label.MsgError_NoRecordId);
            //determining object for the record Id provided i.e. Object in context 
            String objectInContext = String.valueOf(paramWrapper.recordId.getSobjectType());
            
            //verifying provided timeline configuration record 
            if(String.isNotEmpty(paramWrapper.timelineConfigName) && !paramWrapper.timelineConfigName.equalsIgnoreCase(TimelineProperties.DEFAULT_CONFIG)) {
                tcIns = fetchTimelineConfig(paramWrapper.timelineConfigName);
                isTimelineConfigProvided = true;
            }
            //identifying Id for the record for which the history to be fetched 
            twIns.historyTrackedRecordId = identifyHistoryTrackedRecordId(paramWrapper.recordId, objectInContext, paramWrapper.relationshipFieldAPI);
            // ***VALIDATION*** : if the record is not present to show history 
            if(String.isEmpty(twIns.historyTrackedRecordId)) {
                throw new TimelineComponentException(System.Label.MsgError_NoRelatedRecord);
            }
            Schema.DescribeSObjectResult sobjResult = SystemUtilities.getSobjectDescribe(twIns.historyTrackedRecordId.getSObjectType());
            
            String historyTrackedObjectAPIName = sobjResult.getName().toLowerCase();
            // ***VALIDATION*** :validates the data in wrapper and throws exception if data is invalid 
            validateData(twIns, historyTrackedObjectAPIName);
            
            String historyObjectAPIName = identifyHistoryObjectAPI(historyTrackedObjectAPIName, sobjResult);
                
            twIns.timelineHeight = isTimelineConfigProvided ? tcIns.Timeline_Content_Height__c : ''; //height of the content inside timeline 
            twIns.showTableFormatButton = isTimelineConfigProvided ? tcIns.Show_Table_format_button__c : false;  //whether to show button that navigates to OOB table format 
            twIns.showRecordLink = isTimelineConfigProvided ? tcIns.Show_Record_Link__c : false; //whether to show the link that navigates to parent record details 
            twIns.primaryGroupingBy = isTimelineConfigProvided ? tcIns.Primary_Grouping_By__c : TimelineProperties.PRIMARY_GROUPING_DATE; //if there is no first grouping value in parameter, then default to Date
            String contentFormat = (isTimelineConfigProvided && !String.isEmpty(tcIns.Content_Format__c)) ? tcIns.Content_Format__c : TimelineProperties.TIMELINE_CONTENT_FORMAT_CLASSIC;

            //Preparing date filter list to show on UI if respective values on COnfiguration are populated 
            if(isTimelineConfigProvided && String.isNotBlank(tcIns.Visible_Date_Filters__c) && String.isNotBlank(tcIns.Default_Date_Filter__c) && twIns.lstDateFilters.isEmpty()) {
                twIns.showDateFilter = true;

                twIns.lstDateFilters.add(new DropdownWrapper(TimelineProperties.DATE_FILTER_ALL_TIME_VALUE, TimelineProperties.DATE_FILTER_ALL_TIME_LABEL, 0));
                Integer keyValue = 1; 
                for(String dateFilterVal : tcIns.Visible_Date_Filters__c.split(';')) {
                    if(mapLOVDateFilters.containsKey(dateFilterVal)) {
                        twIns.lstDateFilters.add(new DropdownWrapper(dateFilterVal, mapLOVDateFilters.get(dateFilterVal), keyValue) );
                        keyValue++;
                    }
                }
                twIns.selectedDateFilter = mapLOVDateFilters.containsKey(tcIns.Default_Date_Filter__c) ? tcIns.Default_Date_Filter__c : TimelineProperties.DATE_FILTER_ALL_TIME_VALUE ;  
                if(paramWrapper.filters != null && String.isBlank(paramWrapper.filters.dateFilter)) {
                    paramWrapper.filters.dateFilter = twIns.selectedDateFilter;
                } 
            }
            
            GroupSettingsWrapper gsWrapper = TimelineProperties.mapContentFormatToWrapper.get(contentFormat).get(twIns.primaryGroupingBy); //get settings for first level grouping 
            String firstGroupField = gsWrapper.objectFieldAPIName;
            //determining relationship field name 
            String parentIdField  = sobjResult.isCustom() ? TimelineProperties.PARENTID_FIELD : historyTrackedObjectAPIName + TimelineProperties.ID_SUFFIX;
            String currencyField = '', currencyFieldSOQL = '' ;
            if(UserInfo.isMultiCurrencyOrganization()) {
                currencyField = sobjResult.isCustom() ? TimelineProperties.PARENT_CURRENCY_FIELD : historyTrackedObjectAPIName + '.' + TimelineProperties.CURRENCY_ISO_CODE;
                currencyFieldSOQL = ',' + currencyField;
            } 
            //preparing History object SOQL 
            String soql = String.format(TimelineProperties.baseHistorySOQL, 
                            new List<String> { currencyFieldSOQL, historyObjectAPIName, parentIdField, '\'' + twIns.historyTrackedRecordId + '\'', evaluateAdditionalSOQLCriteria(paramWrapper) }
                        );
            system.debug(LoggingLevel.INFO, 'soql=' + soql);
            if(!Test.isRunningTest()) {
                lstRecordHistory = Database.Query(soql);
            }

            if(!lstRecordHistory.isEmpty()) {
                recordCurrencyIsoCode = !Test.isRunningTest() && UserInfo.isMultiCurrencyOrganization() ? (String) SystemUtilities.fetchFieldValue(lstRecordHistory[0], currencyField) : UserInfo.getDefaultCurrency();
                
                //map for top level section and its wrapper, this also contains sub section details in wrapper 
                Map<Object, SectionWrapper> mapSectionWrapper =  new Map<Object, SectionWrapper>(); 
                //map for sub section and its wrapper, this also contains content string details in wrapper. 
                Map<String, SubSectionWrapper> mapSubSectionWrapper =  new Map<String, SubSectionWrapper>(); 
                //map of field Label to list of field API names
                Map<String, Set<String>> mapFieldLabelToAPINames = new Map<String, Set<String>>();
                Integer sectionIdCount = 0, subSectionIdCount = 0; //used for determining Ids for section and sub-sections 
                
                for(Sobject historySobj : lstRecordHistory)
                {
                    //fetching values from the object to use later
                    DateTime createdDate = (DateTime) SystemUtilities.fetchFieldValue(historySobj, 'CreatedDate');
                    String userName = (String)SystemUtilities.fetchFieldValue(historySobj, 'CreatedBy.Name');
                    String modifiedField = (String)SystemUtilities.fetchFieldValue(historySobj, 'Field');
                    Object oldValue = SystemUtilities.fetchFieldValue(historySobj, 'OldValue');
                    Object newValue = SystemUtilities.fetchFieldValue(historySobj, 'NewValue');
                    String dataType = (String) SystemUtilities.fetchFieldValue(historySObj, 'DataType');
                    
                    //checking if the field and new value are valid to move forward. this checks things such as accessbility. 
                    if(!validateFieldSecurity(historyTrackedObjectAPIName, historySobj)) {
                        continue;
                    }
                    //Lookup field's history is divided into 2 different record, one with datatype = entityId has the lookup record Id. Populating the same in a static map to use later. 
                    if(dataType == TimelineProperties.FIELD_DATATYPE_ENTITYID) {
                        if(newValue != null)    mapLookupFieldToId.put(createdDate.getTime() + modifiedField + TimelineProperties.MAPKEY_SUFFIX_NEWVALUE, newValue);
                        if(oldValue != null)    mapLookupFieldToId.put(createdDate.getTime() + modifiedField + TimelineProperties.MAPKEY_SUFFIX_OLDVALUE, oldValue);
                        continue; //continuing execution to next record in for loop to avoid adding the record with id to UI list 
                    }

                    //value for top level grouping field 
                    Object firstGroupValue = SystemUtilities.fetchFieldValue(historySobj, firstGroupField);
                    //determining key for 'mapSectionWrapper' map depending on first level group value type. 
                    Object mapKey = twIns.primaryGroupingBy == TimelineProperties.PRIMARY_GROUPING_DATE ? ((DateTime)firstGroupValue).Year() + '-' + ((DateTime)firstGroupValue).month() : (String) firstGroupValue;
                    //checking if the section already exists in the map
                    SectionWrapper swIns = mapSectionWrapper.containsKey(mapKey) ? mapSectionWrapper.get(mapKey) : new SectionWrapper();
                    //if the id is blank, it means this the first instance of section, define all required values 
                    if(String.isEmpty(swIns.sectionId))  {
                        if(twIns.primaryGroupingBy == TimelineProperties.PRIMARY_GROUPING_FIELD) {
                            String mapKeySF = historyObjectAPIName.toLowerCase() + '|' + ((String)firstGroupValue).toLowerCase();
                            String firstGroupValueFinal = TimelineProperties.mapStandardField.containsKey(mapKeySF) ? TimelineProperties.mapStandardField.get(mapKeySF) : (String)firstGroupValue;
                            String firstLevelFieldLabel = SystemUtilities.fetchFieldLabel(firstGroupValueFinal, historyTrackedObjectAPIName, false);
                            swIns.sectionTitle = TimelineProperties.systemEvents.contains(firstLevelFieldLabel) ? String.format(TimelineProperties.systemEventTemplate, new List<String> { firstLevelFieldLabel }) : firstLevelFieldLabel;
                            swIns.addSearchTag(new List<String> { ((String)swIns.sectionTitle).toLowerCase() } );
                        } else {
                            swIns.sectionTitle = firstGroupValue;
                        }
                        swIns.isDateTime = firstGroupValue instanceof DateTime || firstGroupValue instanceof Date;
                        swIns.sectionId = 'Section-' + sectionIdCount;
                        sectionIdCount++;
                    }
                    
                    String subSectionMapKey = createdDate + String.valueOf(firstGroupValue);
                    //checking if the sub section already exists. 
                    SubSectionWrapper ssIns = mapSubSectionWrapper.containsKey(subSectionMapKey) ?         
                    mapSubSectionWrapper.get(subSectionMapKey) : new SubSectionWrapper();
                    
                    //if the id is blank, it means this the first instance of section, define all required values                    
                    if(String.isEmpty(ssIns.subSectionId)) {
                        String ssTitle = SystemUtilities.populateFormattedString(gsWrapper.subSectionTitle, historySobj, gsWrapper.lstSubSectionFields, new Map<String, Object> { TimelineProperties.KEY_DECIMALSCALE => 3 } );
                        ssIns = new SubSectionWrapper('SubSection-' + subSectionIdCount, ssTitle, createdDate);
                        subSectionIdCount++;
                        swIns.addSubSection(ssIns);
                    }
                    
                    String mapKeySF = historyObjectAPIName.toLowerCase() + '|' + modifiedField.toLowerCase();
                    modifiedField = TimelineProperties.mapStandardField.containsKey(mapKeySF) ? TimelineProperties.mapStandardField.get(mapKeySF) : modifiedField;
                    String fieldLabel = SystemUtilities.fetchFieldLabel(modifiedField, historyTrackedObjectAPIName, false);
                    
                    Set<String> lstFieldAPIs = mapFieldLabelToAPINames.containsKey(fieldLabel) ? mapFieldLabelToAPINames.get(fieldLabel) : new Set<String>();
                    lstFieldAPIs.add(modifiedField);
                    mapFieldLabelToAPINames.put(fieldLabel, lstFieldAPIs);
                    Boolean isEncrypted = SystemUtilities.isEncryptedField(historyTrackedObjectAPIName, modifiedField, false);
                    //creating content wrapper
                    ssIns.addToContent(defineContentWrapper(historySobj, fieldLabel, isEncrypted, gsWrapper, sobjResult));
                    
                    mapSubSectionWrapper.put(subSectionMapKey, ssIns);
                    mapSectionWrapper.put(mapKey, swIns);
                }
                //preparing list for UI with sorting values based on first level grouping 
                twIns.lstSectionWrapper = prepareListForUI(twIns.primaryGroupingBy, mapSectionWrapper, mapFieldLabelToAPINames);
            }            
        }
        catch (Exception ex)  {
            // "Convert" the exception into an AuraHandledException
            throw new AuraHandledException(ex.getMessage());    
        }   
        return twIns;
    }

    /**
     * method to add date filter where clause to SOQL 
     */
    static String addDateClause(String dateFilter) {
        String whereClause = '';
        if(String.isNotEmpty(dateFilter)) {
            if(dateFilter.contains('+')) {
                String subWhereClause = '';
                for(String dFilter : dateFilter.split('\\+')) {
                    dFilter = dFilter.trim();
                    subWhereClause += ' CreatedDate = ' + dFilter + ' OR ';    
                }
                whereClause = ' ( ' + subWhereClause.substring(0, subWhereClause.length() - 3) + ' ) ';
            } else {
                whereClause = ' CreatedDate = ' + dateFilter;    
            }
        }
        return whereClause;
    }

    //method that determines API name for the history object with different scenarios such as different name format for standard objects 
    static String identifyHistoryObjectAPI (String historyTrackedObjectAPIName, Schema.DescribeSObjectResult sobjResult) {
        String historyObjectAPIName = ''; 
        
        if(String.isNotBlank(historyTrackedObjectAPIName)) {
            historyObjectAPIName = TimelineProperties.mapStdObjHistory.containsKey(historyTrackedObjectAPIName) ? TimelineProperties.mapStdObjHistory.get(historyTrackedObjectAPIName) 
                                    : sobjResult.isCustom() ? historyTrackedObjectAPIName.substring(0, historyTrackedObjectAPIName.length() - 1) + TimelineProperties.HISTORY_SUFFIX
                                    : historyTrackedObjectAPIName + TimelineProperties.HISTORY_SUFFIX;
        }

        return historyObjectAPIName;
    }
    
    static Timeline_Configuration__c fetchTimelineConfig(String timelineConfigName) {
        List<Timeline_Configuration__c> timelineConfig = new List<Timeline_Configuration__c> (); 
        
        timelineConfig = [SELECT Id, Primary_Grouping_By__c, Show_Table_format_button__c, Timeline_Content_Height__c, Show_Record_Link__c, Default_Date_Filter__c, Visible_Date_Filters__c,
                                    Content_Format__c, Config_Identifier__c FROM Timeline_Configuration__c WHERE Config_Identifier__c = :timelineConfigName];
        if(timelineConfig.isEmpty()) {
            throw new TimelineComponentException(System.Label.MsgError_NoTimelineConfig);
        }
        
        return timelineConfig[0];
    }

    static string evaluateAdditionalSOQLCriteria(ParamWrapper paramWrapper) {
        String additionalCriteria = ''; 
        
        if(paramWrapper.filters != null && String.isNotEmpty(paramWrapper.filters.dateFilter) && mapLOVDateFilters != null && mapLOVDateFilters.containsKey(paramWrapper.filters.dateFilter) 
            && paramWrapper.filters.dateFilter != TimelineProperties.DATE_FILTER_ALL_TIME_VALUE) { 
            
            additionalCriteria = ' AND ' + addDateClause(paramWrapper.filters.dateFilter);
        }
        return additionalCriteria;
    }
    
    
    //method to identify ID value of the history tracked record to fetch history data
    static String identifyHistoryTrackedRecordId(Id recordId, String objectApiName, String relationshipFieldAPI) {
        Id historyTrackedRecordId;
        if(recordId != null && !String.isEmpty(objectApiName) && !String.isEmpty(relationshipFieldAPI)) {
            if(TimelineProperties.ID_FIELD.equalsIgnoreCase(relationshipFieldAPI)) {
                historyTrackedRecordId = recordId;
            } 
            else {
                String soql = String.format(TimelineProperties.baseIdFilterSOQLWithLimit, new List<String> { relationshipFieldAPI, objectApiName, '\'' + recordId + '\'', '1' });
                for(Sobject sobjRec : Database.query(soql))
                {
                    if(sobjRec.get(relationshipFieldAPI) != null) {
                        historyTrackedRecordId = (Id)sobjRec.get(relationshipFieldAPI);
                        break;
                    }
                }
            }
        }
        return historyTrackedRecordId;
    }
    
    //method that creates the content wrapper, the wrapper that has details about field label, old and new values 
    static ContentWrapper defineContentWrapper(Sobject historySobj, String fieldLabel, Boolean isEncrypted, GroupSettingsWrapper gsWrapper, Schema.DescribeSObjectResult sobjResult)
    {
        String contentString = '';
        List<String> sTags;
        Object oldValue = SystemUtilities.fetchFieldValue(historySobj, 'OldValue');
        Object newValue = SystemUtilities.fetchFieldValue(historySobj, 'NewValue');
        DateTime createdDate = (DateTime) SystemUtilities.fetchFieldValue(historySobj, 'CreatedDate');
        String modifiedField = (String)SystemUtilities.fetchFieldValue(historySobj, 'Field');
        String dataType = (String) SystemUtilities.fetchFieldValue(historySObj, 'DataType');

        String newValueMapKey = createdDate.getTime() + modifiedField + TimelineProperties.MAPKEY_SUFFIX_NEWVALUE;
        String oldValueMapKey = createdDate.getTime() + modifiedField + TimelineProperties.MAPKEY_SUFFIX_OLDVALUE;

        Map<String, Object> mapMethodParams = new Map<String, Object> { TimelineProperties.KEY_FIELDDATATYPE =>  dataType } ;
        if(String.isNotBlank(recordCurrencyIsoCode)) {
            mapMethodParams.put(TimelineProperties.KEY_RECCURRENCY, recordCurrencyIsoCode);
        }
        if(TimelineProperties.FIELD_DATATYPE_CURRENCY.equalsIgnoreCase(dataType) || TimelineProperties.FIELD_DATATPYE_DOUBLE.equalsIgnoreCase(dataType) ) {
            Integer fieldScale = SystemUtilities.getFieldScale(sobjResult.getName(), modifiedField, false);
            mapMethodParams.put(TimelineProperties.KEY_DECIMALSCALE, fieldScale);
        }

        //condition to handle system events such as Record creation, locking, etc.
        if(TimelineProperties.systemEvents.contains(fieldLabel)) {
            contentString = String.format(TimelineProperties.systemEventTemplate, new List<String> { fieldLabel });
            sTags = new List<String> { fieldLabel };
        }
        //when values changes from one to another value, both are not blank
        else if(oldValue != null && newValue != null && !isEncrypted) {
            String mergedTemplate = String.format(gsWrapper.withNewOldValue, new List<String> { fieldLabel } );
            
            if(dataType == TimelineProperties.FIELD_DATATYPE_TEXT && mapLookupFieldToId.containsKey(newValueMapKey) && mapLookupFieldToId.containsKey(oldValueMapKey)) {
                contentString = String.format(mergedTemplate, new List<String> {
                                    '', 
                                    SystemUtilities.buildRecordLinkString((Id) mapLookupFieldToId.get(oldValueMapKey), (String) oldValue), 
                                    SystemUtilities.buildRecordLinkString((Id) mapLookupFieldToId.get(newValueMapKey), (String) newValue) 
                                });
            } else {
                contentString = SystemUtilities.populateFormattedString(mergedTemplate, historySobj, gsWrapper.lstContentFields, mapMethodParams);
            }
            sTags = new List<String> { fieldLabel.toLowerCase(), String.valueof(oldValue).toLowerCase(), String.valueof(newValue).toLowerCase() };
        }
        //when new value is assigned from a blank value 
        else if(newValue != null  && !isEncrypted) {
            String mergedTemplate = String.format(gsWrapper.withNewValueOnly, new List<String> { fieldLabel } );

            if(dataType == TimelineProperties.FIELD_DATATYPE_TEXT && mapLookupFieldToId.containsKey(newValueMapKey) ) {
                contentString = String.format(mergedTemplate, new List<String> {
                                    '', 
                                    '', 
                                    SystemUtilities.buildRecordLinkString((Id) mapLookupFieldToId.get(newValueMapKey), (String) newValue)
                                });
            } else {
                contentString = SystemUtilities.populateFormattedString(mergedTemplate, historySobj, gsWrapper.lstContentFields, mapMethodParams);
            }
            
            sTags = new List<String> { fieldLabel.toLowerCase() , String.valueof(newValue).toLowerCase() };
        }
        //when value is deleted from the field 
        else if(oldValue != null && newValue == null  && !isEncrypted) {
            String mergedTemplate = String.format(gsWrapper.withOldValueOnly, new List<String> { fieldLabel } );

            if(dataType == TimelineProperties.FIELD_DATATYPE_TEXT && mapLookupFieldToId.containsKey(oldValueMapKey)) {
                contentString = String.format(mergedTemplate, new List<String> {
                                    '', 
                                    SystemUtilities.buildRecordLinkString((Id) mapLookupFieldToId.get(oldValueMapKey), (String) oldValue), 
                                    ''
                                });
            } else {
                contentString = SystemUtilities.populateFormattedString(mergedTemplate, historySobj, gsWrapper.lstContentFields, mapMethodParams);
            }
            sTags = new List<String> { fieldLabel.toLowerCase() , String.valueof(oldValue).toLowerCase() };
        }
        //when only change is captured, no value is captured. e.g. text area fields
        else {
            contentString = String.format(gsWrapper.withNoValue, new List<String> { fieldLabel } );
            sTags = new List<String> { fieldLabel.toLowerCase()};
        }
        ContentWrapper cwIns = new ContentWrapper(contentString).addSearchTag(sTags);
        return cwIns;
    }
    //method that prepares a list of wrapper with data sorted according to primary grouping field. 
    static List<SectionWrapper> prepareListForUI(String primaryGroupingBy, Map<Object, SectionWrapper> mapSectionWrapper, Map<String, Set<String>> mapFieldLabelToAPINames) {
        List<SectionWrapper> lstSectionWrapper = new List<SectionWrapper> ();
        lstSectionWrapper = primaryGroupingBy == TimelineProperties.PRIMARY_GROUPING_DATE ? prepareDescendingListForUI(mapSectionWrapper) : 
                                                        prepareAscendingListForUI(primaryGroupingBy, mapSectionWrapper, mapFieldLabelToAPINames);
        return lstSectionWrapper;
    }

    //method to sort data in descending order 
    static List<SectionWrapper> prepareDescendingListForUI(Map<Object, SectionWrapper> mapSectionWrapper) {
        List<SectionWrapper> lstSectionWrapper = new List<SectionWrapper> ();
        List<Object> sectionKeys = new List<Object> (mapSectionWrapper.keyset());
        sectionKeys.sort();
        for(Integer indx = sectionKeys.size() - 1; indx >= 0; indx --) {
            lstSectionWrapper.add(mapSectionWrapper.get(sectionKeys[indx]));
        }
        return lstSectionWrapper;
    }

    //method to sort data in ascending order 
    static List<SectionWrapper> prepareAscendingListForUI(String primaryGroupingBy, Map<Object, SectionWrapper> mapSectionWrapper, Map<String, Set<String>> mapFieldLabelToAPINames) {
        List<SectionWrapper> lstSectionWrapper = new List<SectionWrapper> ();
        List<Object> sectionKeys = primaryGroupingBy == TimelineProperties.PRIMARY_GROUPING_FIELD ? 
        (List<Object>) new List<String> (mapFieldLabelToAPINames.keyset()) : new List<Object> (mapSectionWrapper.keyset());
        sectionKeys.sort();
        for(Object obj : sectionKeys) {
            //if first grouping is Field, then check the sorting for Field Labels (not field APIs)
            if(primaryGroupingBy == TimelineProperties.PRIMARY_GROUPING_FIELD && mapFieldLabelToAPINames.containsKey((String) obj)) {
                for(String fieldAPI : mapFieldLabelToAPINames.get((String) obj)) {
                    lstSectionWrapper.add(mapSectionWrapper.get((fieldAPI)));
                }
            }
            //for other grouping types, do normal Ascending sorting 
            else {
                lstSectionWrapper.add(mapSectionWrapper.get(obj));
            }
        }
        return lstSectionWrapper;
    }

    //method to validate if the object to fetch history records is valid and accessible
    static void validateData(BaseWrapper twIns, String historyTrackedObjectAPIName) {
        if(twIns.historyTrackedRecordId == null) {
            throw new TimelineComponentException(System.Label.MsgError_InvalidId);
        }
        else if(!SystemUtilities.isObjectAccessible(historyTrackedObjectAPIName, false)) {
            throw new TimelineComponentException(System.Label.MsgError_NoObjectAccess);
        }
    }

    //method to check if the current history object record is valid for processing 
    static Boolean validateFieldSecurity(String historyTrackedObjectName, Sobject historySObj) {
        Boolean isValid = true;
        String modifiedField = (String)SystemUtilities.fetchFieldValue(historySObj, 'Field');
        
        if(isValid && !String.isEmpty(modifiedField)) {
            String isAccessible = SystemUtilities.isFieldAccessible(historyTrackedObjectName, modifiedField, false);
            //assigning is valid as TRUE if the field is accessible or not found the in map. The later will happen for standard lookups.
            isValid = isAccessible == TimelineProperties.RETURN_Y || isAccessible == TimelineProperties.RETURN_404;
        }
        return isValid;
    } 
    
    public class TimelineComponentException extends Exception {}
}