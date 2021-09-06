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
@isTest
public with sharing class TimelineComponentTest {
    
    @TestSetup 
    static void makeData(){
        Timeline_Configuration__c tcIns1 = new Timeline_Configuration__c(); 
        tcIns1.Config_Identifier__c = 'Field_Grouping';
        tcIns1.Content_Format__c = TimelineProperties.TIMELINE_CONTENT_FORMAT_MINIMAL;
        tcIns1.Default_Date_Filter__c = 'THIS_FISCAL_YEAR+LAST_FISCAL_YEAR';
        tcIns1.Primary_Grouping_By__c = TimelineProperties.PRIMARY_GROUPING_FIELD;
        tcIns1.Show_Record_Link__c = true;
        tcIns1.Show_Table_format_button__c = true;
        tcIns1.Timeline_Content_Height__c = '800px';
        tcIns1.Visible_Date_Filters__c = 'THIS_QUARTER;LAST_MONTH;THIS_FISCAL_YEAR+LAST_FISCAL_YEAR';
        tcIns1.RecordTypeId = Schema.SObjectType.Timeline_Configuration__c.getRecordTypeInfosByDeveloperName().get('History_Config').getRecordTypeId();
        insert tcIns1;
    }
    
    @isTest
    static void timelineTestGroupByDate() 
    {
        List<sObject> lstAccountHistory = Test.loadData(AccountHistory.sObjectType, 'AccountHistory');
        system.debug('lstAccountHistory='+lstAccountHistory);

        TimelineComponentHelper.lstRecordHistory = (List<AccountHistory>) lstAccountHistory;
        ParamWrapper paramWrap = new ParamWrapper(); 
        paramWrap.recordId = (id) lstAccountHistory[0].get('AccountId');
        paramWrap.relationshipFieldAPI = TimelineProperties.ID_FIELD;
        BaseWrapper twIns = TimelineComponentHelper.getSobjectHistory(paramWrap);

        system.debug('twIns=' + twIns);

        system.assertEquals(twIns.historyTrackedRecordId, paramWrap.recordId);
        system.assert(twIns.lstSectionWrapper.size() > 0);
        system.assertEquals(twIns.lstSectionWrapper[0].isDateTime, true);
    }

    @isTest
    static void timelineTestGroupByField() 
    {
        List<sObject> lstAccountHistory = Test.loadData(AccountHistory.sObjectType, 'AccountHistory');

        TimelineComponentHelper.lstRecordHistory = (List<AccountHistory>) lstAccountHistory;
        ParamWrapper paramWrap = new ParamWrapper(); 
        paramWrap.recordId = (id) lstAccountHistory[0].get('AccountId');
        paramWrap.relationshipFieldAPI = TimelineProperties.ID_FIELD;
        paramWrap.timelineConfigName = 'Field_Grouping'; 
        BaseWrapper twIns = TimelineComponentHelper.getSobjectHistory(paramWrap);

        system.assertEquals(twIns.historyTrackedRecordId, (Id)lstAccountHistory[0].get('AccountId'));
        system.assert(twIns.lstSectionWrapper.size() > 0);
        system.assertEquals(twIns.lstSectionWrapper[0].isDateTime, false);
    }

    @isTest
    static void timelineConfigTriggerTest() {
        Timeline_Configuration__c tcQueried = [SELECT Id FROM Timeline_Configuration__c WHERE Config_Identifier__c = 'Field_Grouping' LIMIT 1];
        Test.startTest();
        tcQueried.Default_Date_Filter__c = 'LAST_WEEK';

        try {
            update tcQueried;
        }
        catch (exception ex) {
            system.assert(ex.getMessage().contains(System.Label.MsgError_TimelineConfigDefaultFilter));
        }
        Test.stopTest();
    }
}