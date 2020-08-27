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
*/
public with sharing class TimelineComponentHelper 
{
    // ***** TEMPLATES FOR SOQL, SECTION, SUBSECTION DATA *****
    //base SQOL for querying history object data 
    static String baseSOQL = 'SELECT Id, Field, CreatedById, CreatedBy.Name, NewValue, OldValue, CreatedDate FROM {0} '
                            + 'WHERE {1}={2}';
    static Integer keyCount = 0;
    //to handle system events which are logged in history tracking 
    static Set<String> systemEvents = new Set<String> 
    {
        'created', 'locked', 'unlocked'
    };
    //some standard fields are listed with different name than the original API name, hence this map used for mapping to correct values.
    static Map<String, String> mapStandardField = new Map<String, String> 
    {
        'accounthistory|textname' => 'Name'
    };
    static string systemEventTemplate = 'Record {0}.';
    //this maps the Top Level grouping with differents settings for each. 
    static Map<String, GroupSettingsWrapper> mapGroupLevelToWrapper = new Map<String, GroupSettingsWrapper> 
    {
        'Date' => new GroupSettingsWrapper('CreatedDate')
            .addSubSectionTemplate('{0} made an update(RELATIVE_DATETIME)', new List<String> { 'CreatedBy.Name'})
            .addFieldMappingTemplate('Changed <strong>{0}</strong> from {1} to <strong>{2}</strong>.', 'Changed <strong>{0}</strong> to <strong>{2}</strong>.', 'Changed <strong>{0}</strong>.', 'Deleted {1} in <strong>{0}</strong>.' ), 
        'User' => new GroupSettingsWrapper('CreatedBy.Name')
            .addSubSectionTemplate('Updated(RELATIVE_DATETIME)', new List<String> { 'CreatedDate'})
            .addFieldMappingTemplate('Changed <strong>{0}</strong> from {1} to <strong>{2}</strong>.', 'Changed <strong>{0}</strong> to <strong>{2}</strong>.', 'Changed <strong>{0}</strong>.', 'Deleted {1} in <strong>{0}</strong>.'  ), 
        'Field' => new GroupSettingsWrapper('Field')
            .addSubSectionTemplate('{0} made an update(RELATIVE_DATETIME)', new List<String> { 'CreatedBy.Name'})
            .addFieldMappingTemplate('Changed from {1} to <strong>{2}</strong>.', 'Changed to <strong>{2}</strong>.', 'Changed the value.', 'Deleted {1} in field.' )
    };
    // ***** WRAPPER FOR SECTION, SUBSECTION TEMPLATE DATA *****
    public class GroupSettingsWrapper
    {
        public String objectFieldAPIName;
        public String subSectionTitle;
        public List<String> lstSubSectionFields;
        public String withNewValueOnly;
        public String withNewOldValue;
        public String withNoValue;
        public String withOldValueOnly;
        public List<String> lstContentFields = new List<String> ();
        //constructor that defines field API name in parameter
        public GroupSettingsWrapper(String fieldAPIName)
        {
            this.objectFieldAPIName = fieldAPIName;
            lstContentFields = new List<String> {'Field', 'OldValue', 'NewValue' }; 
        }
        //method for adding title for sub section template and its merge fields 
        public GroupSettingsWrapper addSubSectionTemplate(String subSectionTitle, List<String> lstSubSectionFields)
        {
            this.subSectionTitle = subSectionTitle;
            this.lstSubSectionFields = lstSubSectionFields;
            return this;
        }
        //method for adding string templates for content strings with 3 different scenarios. 
        public GroupSettingsWrapper addFieldMappingTemplate(String withNewOldValue, String withNewValueOnly, String withNoValue, String withOldValueOnly)
        {
            this.withNewOldValue = withNewOldValue;
            this.withNewValueOnly = withNewValueOnly;
            this.withNoValue = withNoValue;
            this.withOldValueOnly = withOldValueOnly;
            return this;
        }
    }

    @TestVisible
    static List<SObject> lstRecordHistory = new List<Sobject> ();
    
    //method that is invoked from the LWC to fetch history object data. 
    @AuraEnabled(cacheable=true)
    public static TimelineWrapper getSobjectHistory(Id recordId, String objectInContext, String relationshipFieldAPIName, String historyTrackedObjectAPIName, String historyObjectAPIName, String firstLevelGrouping)
    {
        TimelineWrapper twIns = new TimelineWrapper();
        try
        {
            //making sure parameters passed are not null 
            if(recordId != null && !String.isEmpty(objectInContext) && !String.isEmpty(relationshipFieldAPIName) &&
            !String.isEmpty(historyTrackedObjectAPIName) && !String.isEmpty(historyObjectAPIName))
            {
                twIns.historyTrackedRecordId = identifyHistoryTrackedRecordId(recordId, objectInContext, relationshipFieldAPIName);
                if(isObjectValid(twIns, historyTrackedObjectAPIName))
                {
                    String historyTrackedObjectNameLower = historyTrackedObjectAPIName.toLowerCase();
                    //if there is no first grouping value in parameter, then default to Date 
                    firstLevelGrouping = String.isEmpty(firstLevelGrouping) ? 'Date' : firstLevelGrouping; 
                    GroupSettingsWrapper gsWrapper = mapGroupLevelToWrapper.get(firstLevelGrouping); //get settings for first level grouping 
                    String firstGroupField = gsWrapper.objectFieldAPIName;
                    Boolean isCustomObj = tc_SystemUtilities.isCustomObject(historyTrackedObjectNameLower, false);
                    //determining relationship field name 
                    String parentIdField  = isCustomObj ? 'ParentId' : historyTrackedObjectAPIName + 'Id';
                    //preparing History object SOQL 
                    String soql = String.format(baseSOQL, new List<String> { historyObjectAPIName, parentIdField, '\'' + twIns.historyTrackedRecordId + '\''});
                    soql += ' ORDER BY CreatedDate DESC ';
                    
                    //map for top level section and its wrapper, this also contains sub section details in wrapper 
                    Map<Object, SectionWrapper> mapSectionWrapper =  new Map<Object, SectionWrapper>(); 
                    //map for sub section and its wrapper, this also contains content string details in wrapper. 
                    Map<String, SubSectionWrapper> mapSubSectionWrapper =  new Map<String, SubSectionWrapper>(); 
                    //map of field Label to list of field API names
                    Map<String, Set<String>> mapFieldLabelToAPINames = new Map<String, Set<String>>();
                    Integer sectionIdCount = 0, subSectionIdCount = 0; //used for determining Ids for section and sub-sections 
                    
                    if(!Test.isRunningTest())
                    {
                        lstRecordHistory = Database.Query(soql);
                    }
                    for(Sobject historySobj : lstRecordHistory)
                    {
                        //fetching values from the object to use later
                        DateTime createdDate = (DateTime) tc_SystemUtilities.fetchFieldValue(historySobj, 'CreatedDate');
                        String userName = (String)tc_SystemUtilities.fetchFieldValue(historySobj, 'CreatedBy.Name');
                        String modifiedField = (String)tc_SystemUtilities.fetchFieldValue(historySobj, 'Field');
                        Object oldValue = tc_SystemUtilities.fetchFieldValue(historySobj, 'OldValue');
                        Object newValue = tc_SystemUtilities.fetchFieldValue(historySobj, 'NewValue');

                        //checking if the field and new value are valid to move forward. this checks things such as accessbility. 
                        if(!isRecordValid(historyTrackedObjectNameLower, historySobj))
                        {
                            continue;
                        }
                        //value for top level grouping field 
                        Object firstGroupValue = tc_SystemUtilities.fetchFieldValue(historySobj, firstGroupField);
                        //determining key for 'mapSectionWrapper' map depending on first level group value type. 
                        Object mapKey = firstLevelGrouping == 'Date' ? 
                                        ((DateTime)firstGroupValue).Year() + '-' + ((DateTime)firstGroupValue).month() : 
                                        (String) firstGroupValue;
                        
                        //checking if the section already exists in the map
                        SectionWrapper swIns = mapSectionWrapper.containsKey(mapKey) ? mapSectionWrapper.get(mapKey) : new SectionWrapper();
                        
                        //if the id is blank, it means this the first instance of section, define all required values 
                        if(String.isEmpty(swIns.sectionId)) 
                        {
                            if(firstLevelGrouping == 'Field')
                            {
                                String mapKeySF = historyObjectAPIName.toLowerCase() + '|' + ((String)firstGroupValue).toLowerCase();
                                String firstGroupValueFinal = mapStandardField.containsKey(mapKeySF) ? mapStandardField.get(mapKeySF) : (String)firstGroupValue;
                                String firstLevelFieldLabel = tc_SystemUtilities.fetchFieldLabel(firstGroupValueFinal, historyTrackedObjectNameLower, false);
                                swIns.sectionTitle = systemEvents.contains(firstLevelFieldLabel) ? 
                                            String.format(systemEventTemplate, new List<String> { firstLevelFieldLabel }) :
                                            firstLevelFieldLabel;
                                swIns.addSearchTag(new List<String> { ((String)swIns.sectionTitle).toLowerCase() } );
                            }
                            else
                            {
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
                        if(String.isEmpty(ssIns.subSectionId))
                        {
                            String ssTitle = tc_SystemUtilities.populateFormattedString(gsWrapper.subSectionTitle, historySobj, gsWrapper.lstSubSectionFields, 3);
                            ssIns = new SubSectionWrapper('SubSection-' + subSectionIdCount, ssTitle, createdDate);
                            subSectionIdCount++;
                            swIns.addSubSection(ssIns);
                        }

                        //String fieldAPIName = modifiedField;
                        String mapKeySF = historyObjectAPIName.toLowerCase() + '|' + modifiedField.toLowerCase();
                        modifiedField = mapStandardField.containsKey(mapKeySF) ? mapStandardField.get(mapKeySF) : modifiedField;
                        String fieldLabel = tc_SystemUtilities.fetchFieldLabel(modifiedField, historyTrackedObjectNameLower, false);

                        Set<String> lstFieldAPIs = mapFieldLabelToAPINames.containsKey(fieldLabel) ? 
                                                    mapFieldLabelToAPINames.get(fieldLabel) : new Set<String>();
                        lstFieldAPIs.add(modifiedField);
                        mapFieldLabelToAPINames.put(fieldLabel, lstFieldAPIs);
                        Boolean isEncrypted = tc_SystemUtilities.isEncryptedField(historyTrackedObjectNameLower, modifiedField, false);
                        //creating content wrapper
                        ssIns.addToContent(defineContentWrapper(historySobj, fieldLabel, isEncrypted, gsWrapper));
                        
                        mapSubSectionWrapper.put(subSectionMapKey, ssIns);
                        mapSectionWrapper.put(mapKey, swIns);
                    }
                    //preparing list for UI with sorting values based on first level grouping 
                    twIns.lstSectionWrapper = prepareListForUI(firstLevelGrouping, mapSectionWrapper, mapFieldLabelToAPINames);
                }
            }
        }
        catch (Exception e) 
        {
            // "Convert" the exception into an AuraHandledException
            throw new AuraHandledException(e.getMessage());    
        }   
        return twIns;
    }
    //method to identify ID value of the history tracked record to fetch history data
    static String identifyHistoryTrackedRecordId(Id recordId, String objectApiName, String relationshipFieldAPI)
    {
        Id historyTrackedRecordId;
        system.debug('objectApiName='+objectApiName);
        system.debug('relationshipFieldAPI='+relationshipFieldAPI);
        if(recordId != null && !String.isEmpty(objectApiName) && !String.isEmpty(relationshipFieldAPI))
        {
            if(relationshipFieldAPI.toLowerCase() == 'id')
            {
                historyTrackedRecordId = recordId;
            }
            else
            {
                String soql = 'SELECT ' + relationshipFieldAPI + ' FROM ' + objectApiName + ' WHERE Id = \'' + recordId + '\'';
                for(Sobject sobjRec : Database.query(soql))
                {
                    historyTrackedRecordId = (Id)sobjRec.get(relationshipFieldAPI);
                    break;
                }
            }
        }
        
        return historyTrackedRecordId;
    }

    //method that creates the content wrapper, the wrapper that has details about field label, old and new values 
    static ContentWrapper defineContentWrapper(Sobject historySobj, String fieldLabel, Boolean isEncrypted, GroupSettingsWrapper gsWrapper)
    {
        String contentString = '';
        List<String> sTags;
        Object oldValue = tc_SystemUtilities.fetchFieldValue(historySobj, 'OldValue');
        Object newValue = tc_SystemUtilities.fetchFieldValue(historySobj, 'NewValue');
        //condition to handle system events such as Record creation, locking, etc.
        if(systemEvents.contains(fieldLabel))
        {
            contentString = String.format(systemEventTemplate, new List<String> { fieldLabel });
            sTags = new List<String> { fieldLabel };
        }
        //when values changes from one to another value, both are not blank
        else if(oldValue != null && newValue != null && !isEncrypted)
        {
            String mergedTemplate = String.format(gsWrapper.withNewOldValue, new List<String> { fieldLabel } );
            contentString = tc_SystemUtilities.populateFormattedString(mergedTemplate, historySobj, gsWrapper.lstContentFields, 3);
            sTags = new List<String> { fieldLabel.toLowerCase(), String.valueof(oldValue).toLowerCase(), String.valueof(newValue).toLowerCase() };
        }
        //when new value is assigned from a blank value 
        else if(newValue != null  && !isEncrypted)
        {
            String mergedTemplate = String.format(gsWrapper.withNewValueOnly, new List<String> { fieldLabel } );
            contentString = tc_SystemUtilities.populateFormattedString(mergedTemplate, historySobj, gsWrapper.lstContentFields, 3);
            sTags = new List<String> { fieldLabel.toLowerCase() , String.valueof(newValue).toLowerCase() };
        }
        //when value is deleted from the field 
        else if(oldValue != null && newValue == null  && !isEncrypted)
        {
            String mergedTemplate = String.format(gsWrapper.withOldValueOnly, new List<String> { fieldLabel } );
            contentString = tc_SystemUtilities.populateFormattedString(mergedTemplate, historySobj, gsWrapper.lstContentFields, 3);
            sTags = new List<String> { fieldLabel.toLowerCase() , String.valueof(oldValue).toLowerCase() };
        }
        //when only change is captured, no value is captured. e.g. text area fields
        else
        {
            contentString = String.format(gsWrapper.withNoValue, new List<String> { fieldLabel } );
            sTags = new List<String> { fieldLabel.toLowerCase()};
        }
        ContentWrapper cwIns = new ContentWrapper(contentString).addSearchTag(sTags);
        return cwIns;
    }
    //method that prepares a list of wrapper with data sorted according to primary grouping field. 
    static List<SectionWrapper> prepareListForUI(String firstLevelGrouping, Map<Object, SectionWrapper> mapSectionWrapper, 
                                        Map<String, Set<String>> mapFieldLabelToAPINames)
    {
        List<SectionWrapper> lstSectionWrapper = new List<SectionWrapper> ();
        lstSectionWrapper = firstLevelGrouping == 'Date' ? 
                        prepareDescendingListForUI(firstLevelGrouping, mapSectionWrapper) :
                        prepareAscendingListForUI(firstLevelGrouping, mapSectionWrapper, mapFieldLabelToAPINames);
        return lstSectionWrapper;
    }
    //method to sort data in descending order 
    static List<SectionWrapper> prepareDescendingListForUI(String firstLevelGrouping, Map<Object, SectionWrapper> mapSectionWrapper)
    {
        List<SectionWrapper> lstSectionWrapper = new List<SectionWrapper> ();
        List<Object> sectionKeys = new List<Object> (mapSectionWrapper.keyset());
        sectionKeys.sort();
        for(Integer indx = sectionKeys.size() - 1; indx >= 0; indx --)
        {
            lstSectionWrapper.add(mapSectionWrapper.get(sectionKeys[indx]));
        }
        return lstSectionWrapper;
    }
    //method to sort data in ascending order 
    static List<SectionWrapper> prepareAscendingListForUI(String firstLevelGrouping, Map<Object, SectionWrapper> mapSectionWrapper, Map<String, Set<String>> mapFieldLabelToAPINames)
    {
        List<SectionWrapper> lstSectionWrapper = new List<SectionWrapper> ();
        List<Object> sectionKeys = firstLevelGrouping == 'Field' ? 
                   (List<Object>) new List<String> (mapFieldLabelToAPINames.keyset()) : new List<Object> (mapSectionWrapper.keyset());
        sectionKeys.sort();
        for(Object obj : sectionKeys)
        {
            //if first grouping is Field, then check the sorting for Field Labels (not field APIs)
            if(firstLevelGrouping == 'Field' && mapFieldLabelToAPINames.containsKey((String) obj))
            {
                for(String fieldAPI : mapFieldLabelToAPINames.get((String) obj))
                {
                    lstSectionWrapper.add(mapSectionWrapper.get((fieldAPI)));
                }
            }
            //for other grouping types, do normal Ascending sorting 
            else
            {
                lstSectionWrapper.add(mapSectionWrapper.get(obj));
            }
        }
        return lstSectionWrapper;
    }
    //method to validate if the object to fetch history records is valid and accessible
    static Boolean isObjectValid(TimelineWrapper twIns, String historyTrackedObjectAPIName)
    {
        Boolean isValid = true;
        if(twIns.historyTrackedRecordId == null)
        {
            twIns.displayMessage = System.Label.tc_invalidIdMessage;
            isValid = false;
        }
        else if(!tc_SystemUtilities.isObjectAccessible(historyTrackedObjectAPIName, false))
        {
            twIns.displayMessage = System.Label.tc_noObjectAccessMessage;
            isValid = false;
        }
        return isValid;
    }
    //method to check if the current history object record is valid for processing 
    static Boolean isRecordValid(String historyTrackedObjectName, Sobject historySObj)
    {
        Boolean isValid = true;
        String modifiedField = (String)tc_SystemUtilities.fetchFieldValue(historySObj, 'Field');
        Object newValue = tc_SystemUtilities.fetchFieldValue(historySObj, 'NewValue');
        Object oldValue = tc_SystemUtilities.fetchFieldValue(historySObj, 'OldValue');

        //if the tracked value is Id then skip it. 
        // *****Current HISTORY OBJECT QUERY for lookup, master detail fields gives two recrds, one with Id and another with label. Skipping the Id 
        //value for now. This will be fixed later to show proper link for the reference fields in history. 
        if((newValue != null && newValue instanceof Id) || ( oldValue != null && oldValue instanceof Id))
        {
            isValid = false;
        }
        if(isValid && !String.isEmpty(modifiedField))
        {
            String isAccessible = tc_SystemUtilities.isFieldAccessible(historyTrackedObjectName, modifiedField, false);
            //assigning is valid as TRUE if the field is accessible or not found the in map. The later will happen for standard lookups.
            isValid = isAccessible == 'y' || isAccessible == '404';
        }
        return isValid;
    }

    public class TimelineWrapper
    {
        @AuraEnabled public Id historyTrackedRecordId;
        @AuraEnabled public String displayMessage;
        @AuraEnabled public List<SectionWrapper> lstSectionWrapper;

        public TimelineWrapper()
        {
            lstSectionWrapper = new List<SectionWrapper>();
        }
    }

    //Wrapper class for Top level Section
    public class SectionWrapper
    {
        @AuraEnabled public Object sectionTitle;
        @AuraEnabled public Boolean isDateTime;
        @AuraEnabled public String sectionId;
        @AuraEnabled public String searchTags;

        @AuraEnabled public List<SubSectionWrapper> lstSubSections;

        public SectionWrapper()
        {
            lstSubSections = new List<SubSectionWrapper> ();
            this.searchTags = '';
        }

        public void addSubSection(SubSectionWrapper ssIns)
        {
            this.lstSubSections.add(ssIns);
        }

        public void addSearchTag(List<String> searchTags)
        {
            if(searchTags != null && searchTags.size() > 0)
            {
                this.searchTags += searchTags.toString() + ',';
            }
        }
    }
    //Wrapper for Sub section, children to Section Wrapper
    public Class SubSectionWrapper
    {
        @AuraEnabled public String subSectionTitle;
        @AuraEnabled public DateTime relativeDateTime;
        @AuraEnabled public DateTime actualDateTime;
        @AuraEnabled public String subSectionId; 
        

        @AuraEnabled public List<ContentWrapper> lstContentString;

        public SubSectionWrapper() 
        { }

        public SubSectionWrapper(String subSectionId, String subSectionTitle, DateTime actualDateTime)
        {
            lstContentString = new List<ContentWrapper>();
            this.subSectionId = subSectionId;
            this.subSectionTitle = subSectionTitle;
            this.actualDateTime = actualDateTime;
            this.relativeDateTime = actualDateTime;
        }

        public void addToContent(ContentWrapper cwIns)
        {
            this.lstContentString.add(cwIns);
        }
    }
    //wrapper class for lowest level content wrapper, child for Sub-section Wrapper
    public Class ContentWrapper
    {
        @AuraEnabled public string contentString;
        @AuraEnabled public Integer contentKey;      
        @AuraEnabled public String searchTags; 
        @AuraEnabled public Boolean doShow; 

        public ContentWrapper(String contentString)
        {
            this.contentString = contentString;
            this.contentKey = keyCount;
            this.searchTags = '';
            this.doShow = true;
            keyCount++;
        }

        public ContentWrapper addSearchTag(List<String> searchTags)
        {
            if(searchTags != null && searchTags.size() > 0)
            {
                this.searchTags += searchTags.toString() + ',';
            }
            return this;
        }
    }
}