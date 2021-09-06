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
Trigger handler class for Timeline_Configuration__c object trigger 
*/
public with sharing class TimelineConfigurationHandler {

    public TimelineConfigurationHandler() { }

    /*
     * method for before insert trigger event
     */ 
    public void OnBeforeInsert(List<Timeline_Configuration__c> lstNewTimelineConfigs) {
        for(Timeline_Configuration__c tcIns : lstNewTimelineConfigs) {
            validateDateFilters(tcIns);
        }
    }
    /*
     * method for before update trigger event
     */ 
    public void OnBeforeUpdate(List<Timeline_Configuration__c> lstNewTimelineConfigs) {
        for(Timeline_Configuration__c tcIns : lstNewTimelineConfigs) {
            validateDateFilters(tcIns);
        }
    }
    /*
     * method for date filter validation 
     */ 
    private void validateDateFilters(Timeline_Configuration__c tcIns) {
        if(String.isNotBlank(tcIns.Visible_Date_Filters__c) && String.isNotBlank(tcIns.Default_Date_Filter__c) && !tcIns.Visible_Date_Filters__c.contains(tcIns.Default_Date_Filter__c) 
            && !TimelineProperties.DATE_FILTER_ALL_TIME_VALUE.equalsIgnoreCase(tcIns.Default_Date_Filter__c)) {
            tcIns.Default_Date_Filter__c.addError(System.Label.MsgError_TimelineConfigDefaultFilter);
        }
    }
}