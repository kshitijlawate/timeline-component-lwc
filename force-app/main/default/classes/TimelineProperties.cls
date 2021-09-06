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
Apex class with list of dynamic, template and constant properties 

*/
public with sharing class TimelineProperties {
    /* *** CONSTANTS *** */
    //suffix for OOB fields 
    public static final String HISTORY_SUFFIX = 'History'; 
    public static final String ID_SUFFIX = 'Id';

    //api name for fields 
    public static final String ID_FIELD = 'id';
    public static final String PARENTID_FIELD = 'ParentId'; 
    public static final String PARENT_CURRENCY_FIELD = 'Parent.CurrencyIsoCode'; 
    public static final String CURRENCY_ISO_CODE = 'CurrencyIsoCode';

    //date type values received in history data query
    public static final String FIELD_DATATYPE_ENTITYID = 'EntityId';
    public static final String FIELD_DATATYPE_TEXT = 'Text';
    public static final String FIELD_DATATYPE_CURRENCY = 'Currency';
    public static final String FIELD_DATATPYE_DOUBLE = 'Double';

    //date filter values 
    public static final String DATE_FILTER_ALL_TIME_VALUE = 'ALL_TIME';
    public static final String DATE_FILTER_ALL_TIME_LABEL = 'All Time';

    //content format LOV available on Timeline config 
    public static final String TIMELINE_CONTENT_FORMAT_CLASSIC = 'Classic';
    public static final String TIMELINE_CONTENT_FORMAT_MINIMAL = 'Minimal';
    
    //primary grouping by values 
    public static final String PRIMARY_GROUPING_DATE = 'Date';
    public static final String PRIMARY_GROUPING_USER = 'User';
    public static final String PRIMARY_GROUPING_FIELD = 'Field';

    //suffix for map key 
    public static final String MAPKEY_SUFFIX_NEWVALUE = 'new_value';
    public static final String MAPKEY_SUFFIX_OLDVALUE = 'old_value';

    //return constant for field accessibility 
    public static final String RETURN_Y = 'y';
    public static final String RETURN_N = 'n';
    public static final String RETURN_404 = '404';

    //param map keys
    public static final String KEY_FIELDDATATYPE = 'FieldDataType';
    public static final String KEY_RECCURRENCY = 'RecordCurrency';
    public static final String KEY_DECIMALSCALE = 'DecimalScale';
    
    //defualt config value when none is provided 
    public static final String DEFAULT_CONFIG = 'default';

    /* *** TEMPLATES *** */
    // ***** TEMPLATES FOR SOQL, SECTION, SUBSECTION DATA *****
    //base SQOL for querying history object data 
    public static String baseHistorySOQL = 'SELECT Id, Field, CreatedById, CreatedBy.Name, NewValue, OldValue, CreatedDate, DataType {0} FROM {1} WHERE {2}={3} {4} ORDER BY CreatedDate DESC, Field, DataType';
    public static String baseIdFilterSOQLWithLimit = 'SELECT {0} FROM {1} WHERE Id = {2} LIMIT {3}';

    //to handle system events which are logged in history tracking 
    public static Set<String> systemEvents = new Set<String>  {
        'created', 'locked', 'unlocked'
    };
    public static string systemEventTemplate = 'Record {0}.';
    //some standard fields are listed with different name than the original API name, hence this map used for mapping to correct values.
    public static Map<String, String> mapStandardField = new Map<String, String>  {
        'accounthistory|textname' => 'Name'
    };
    //some standard objects have different format for history object api name 
    public static Map<String, String> mapStdObjHistory = new Map<String, String> {
        'opportunity' => 'opportunityfieldhistory'
    };

    //this maps the Top Level grouping with differents settings for each. 
    public static Map<String, GroupSettingsWrapper> mapGroupLevelToWrapperClassic = new Map<String, GroupSettingsWrapper>  {
        PRIMARY_GROUPING_DATE => new GroupSettingsWrapper('CreatedDate')
            .addSubSectionTemplate(
                '{0} made an update(RELATIVE_DATETIME)', 
                new List<String> { 'CreatedBy.Name' }
            )
            .addFieldMappingTemplate(
                'Changed <strong>{0}</strong> from {1} to <strong>{2}</strong>.', 
                'Changed <strong>{0}</strong> to <strong>{2}</strong>.', 
                'Changed <strong>{0}</strong>.', 
                'Deleted {1} in <strong>{0}</strong>.' 
            ),
        PRIMARY_GROUPING_USER => new GroupSettingsWrapper('CreatedBy.Name')
            .addSubSectionTemplate(
                'Updated(RELATIVE_DATETIME)', 
                new List<String> { 'CreatedDate'}
            )
            .addFieldMappingTemplate(
                'Changed <strong>{0}</strong> from {1} to <strong>{2}</strong>.', 
                'Changed <strong>{0}</strong> to <strong>{2}</strong>.', 
                'Changed <strong>{0}</strong>.', 
                'Deleted {1} in <strong>{0}</strong>.'  
            ), 
        PRIMARY_GROUPING_FIELD => new GroupSettingsWrapper('Field')
            .addSubSectionTemplate(
                '{0} made an update(RELATIVE_DATETIME)', 
                new List<String> { 'CreatedBy.Name'}
            )
            .addFieldMappingTemplate(
                'Changed from {1} to <strong>{2}</strong>.', 
                'Changed to <strong>{2}</strong>.', 
                'Changed the value.', 
                'Deleted {1} in field.' 
            )
    };
    public static Map<String, GroupSettingsWrapper> mapGroupLevelToWrapperMinimal = new Map<String, GroupSettingsWrapper>  {
        PRIMARY_GROUPING_DATE => new GroupSettingsWrapper('CreatedDate')
            .addSubSectionTemplate(
                '{0} made an update(RELATIVE_DATETIME)', 
                new List<String> { 'CreatedBy.Name'}
            )
            .addFieldMappingTemplate(
                '<strong>{0}</strong>: {1} → {2}', 
                '<strong>{0}</strong>: {2}', 
                'Updated <strong>{0}</strong>.', 
                '<strong>{0}</strong>: <strike>{1}</strike>' 
            ), 
        PRIMARY_GROUPING_USER => new GroupSettingsWrapper('CreatedBy.Name')
            .addSubSectionTemplate(
                'Updated(RELATIVE_DATETIME)', 
                new List<String> { 'CreatedDate'}
            )
            .addFieldMappingTemplate(
                '<strong>{0}</strong>: {1} → {2}', 
                '<strong>{0}</strong>: {2}', 
                'Updated <strong>{0}</strong>.', 
                '<strong>{0}</strong>: <strike>{1}</strike>' 
            ), 
        PRIMARY_GROUPING_FIELD => new GroupSettingsWrapper('Field')
            .addSubSectionTemplate(
                '{0} made an update(RELATIVE_DATETIME)', 
                new List<String> { 'CreatedBy.Name'}
            )
            .addFieldMappingTemplate(
                '{1} → <strong>{2}</strong>', 
                '{2}', 
                'Updated the value.', 
                '<strike>{1}</strike>' 
            )
    };

    //mapping for content format to primary level group settings 
    public static Map<String, Map<String, GroupSettingsWrapper>> mapContentFormatToWrapper = new Map<String, Map<String, GroupSettingsWrapper>> {
        TIMELINE_CONTENT_FORMAT_CLASSIC => mapGroupLevelToWrapperClassic, TIMELINE_CONTENT_FORMAT_MINIMAL => mapGroupLevelToWrapperMinimal
    };
}