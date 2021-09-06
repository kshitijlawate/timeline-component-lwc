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
Class with resusable utilities to use within any apex class in system
*/
public class SystemUtilities {
	//map with sobject name as key and sobject type as value 
	static Map<String,Schema.SObjectType> globalDescribe;
	//map wth object name as Key and Sobject describe result as value 
	static Map<String, Schema.DescribeSObjectResult> mapSobjNameToObjDescribe = new Map<String, Schema.DescribeSObjectResult>();
	//map of fields for the object with Field API name as key 
	static Map<String, Schema.SObjectField> mapSObjectField = new Map<String, Schema.SObjectField>();

	/**
	 * method to perform describe sobject only once in a transaction and return it from static variable on multiple calls
	 */
	public static Map<String,Schema.SObjectType> getGlobalDescribe() {
		if(globalDescribe == null) {
			globalDescribe = Schema.getGlobalDescribe(); 
		}
		return globalDescribe;
	}
	/**
	 * method that accepts sobject name as parameter and returns sobject describe result
	 */
	public static Schema.DescribeSObjectResult getSobjectDescribe(String mapSobjName) {
		Schema.DescribeSObjectResult dsResult;

		if(!mapSobjNameToObjDescribe.containsKey(mapSobjName)) {
			Map<String,Schema.SObjectType> mapGD = getGlobalDescribe();
			if(mapGD.containsKey(mapSobjName)) {
				dsResult = mapGD.get(mapSobjName).getDescribe();
				mapSobjNameToObjDescribe.put(mapSobjName, dsResult);
			}
		} else  {
			dsResult = mapSobjNameToObjDescribe.get(mapSobjName);  
		}
		return dsResult;
	}

	/**
	 * method that accepts sobject name as parameter and returns sobject describe result
	 */
	public static Schema.DescribeSObjectResult getSobjectDescribe(String mapSobjName, Boolean doGlobalDescribe) {
		Schema.DescribeSObjectResult dsResult;

		if(!mapSobjNameToObjDescribe.containsKey(mapSobjName)) {
			if(doGlobalDescribe) {
				dsResult = getSobjectDescribe(mapSobjName);
			} else {
				Sobject sobjIns = (SObject)Type.forName(mapSobjName).newInstance();
				dsResult = sobjIns.getSObjectType().getDescribe();
				mapSobjNameToObjDescribe.put(mapSobjName, dsResult);
			}
		} else  {
			dsResult = mapSobjNameToObjDescribe.get(mapSobjName);  
		}
		return dsResult;
	}
	/**
	 * method that accepts sobject instance as parameter and returns sobject describe result
	 */
	public static Schema.DescribeSObjectResult getSobjectDescribe(Sobject sobjIns) {
		Schema.DescribeSObjectResult dsResult;
		if(sobjIns != null) {
			dsResult = sobjIns.getSObjectType().getDescribe();
			mapSobjNameToObjDescribe.put(dsResult.getName(), dsResult);
		}
		return dsResult;
	}

	/**
	 * method that accepts sobject instance as parameter and returns sobject describe result
	 */
	public static Schema.DescribeSObjectResult getSobjectDescribe(Schema.SObjectType sobjectType) {
		Schema.DescribeSObjectResult dsResult;
		if(sobjectType != null) {
			dsResult = sobjectType.getDescribe();
			mapSobjNameToObjDescribe.put(dsResult.getName(), dsResult);
		}
		return dsResult;
	}

	/**
	 * method to check if the object is accessible to logged in user  
	*/
	public static Boolean isObjectAccessible(String sObjectName, Boolean doGlobalDescribe) {
		return SystemUtilities.getSobjectDescribe(sObjectName, doGlobalDescribe).isAccessible();
	}

	/**
	 * method to check if the field is accessbile to current user
	 */ 
	public static String isFieldAccessible(String sObjectName, String fieldAPIName, Boolean doGlobalDescribe) {
		String isAccessible = TimelineProperties.RETURN_N;
		String fieldAPINameLower = fieldAPIName.toLowerCase();
		String fieldAPINameSuffixed = fieldAPINameLower + TimelineProperties.ID_SUFFIX;
		if(!mapSObjectField.containsKey(fieldAPINameLower) && !mapSObjectField.containsKey(fieldAPINameSuffixed)) {
			mapSObjectField = SystemUtilities.getSobjectDescribe(sObjectName, doGlobalDescribe).fields.getMap();
		}
		if(mapSObjectField.containsKey(fieldAPINameLower)) {
			isAccessible = mapSObjectField.get(fieldAPINameLower).getDescribe().isAccessible() ? TimelineProperties.RETURN_Y : TimelineProperties.RETURN_N;
		}
		//the field is not found in the map... this could happen for standard lookups on History objects 
		else {
			if(mapSObjectField.containsKey(fieldAPINameSuffixed)) {
				isAccessible = mapSObjectField.get(fieldAPINameSuffixed).getDescribe().isAccessible() ? TimelineProperties.RETURN_Y : TimelineProperties.RETURN_N;
			} else {
				isAccessible = TimelineProperties.RETURN_404;
			}
		}
		return isAccessible;
	}
	/**
	 * method to get display type of the field such as Percent, Currency which are Decimal type in backend. 
	 */
	public static Schema.DisplayType getFieldDisplayType(String sobjectName, String fieldAPIName, Boolean doGlobalDescribe ) {
		Schema.DisplayType returnVal;
		String fieldAPINameLower = fieldAPIName.toLowerCase();
		if(!mapSObjectField.containsKey(fieldAPINameLower)) {
			mapSObjectField = SystemUtilities.getSobjectDescribe(sObjectName, doGlobalDescribe).fields.getMap();
		}
		if(mapSObjectField.containsKey(fieldAPINameLower)) {
			returnVal = mapSObjectField.get(fieldAPINameLower).getDescribe().getType() ;
		}
		return returnVal;
	}

	/**
	 * method to get display type of the field such as Percent, Currency which are Decimal type in backend. 
	 */
	public static Integer getFieldScale(String sobjectName, String fieldAPIName, Boolean doGlobalDescribe ) {
		Integer returnVal;
		
		String fieldAPINameLower = fieldAPIName.toLowerCase();
		if(!mapSObjectField.containsKey(fieldAPINameLower)) {
			mapSObjectField = SystemUtilities.getSobjectDescribe(sObjectName, doGlobalDescribe).fields.getMap();
		}
		if(mapSObjectField.containsKey(fieldAPINameLower)) {
			returnVal = mapSObjectField.get(fieldAPINameLower).getDescribe().getScale();
		}
		return returnVal;
	}

	/**
	 * method to check if the field is encrypted
	 */ 
	public static Boolean isEncryptedField(String sObjectName, String fieldAPIName, Boolean doGlobalDescribe) {
		Boolean isEncrypted = false;
		String fieldAPINameLower = fieldAPIName.toLowerCase();
		if(!mapSObjectField.containsKey(fieldAPINameLower)) {
			mapSObjectField = SystemUtilities.getSobjectDescribe(sObjectName, doGlobalDescribe).fields.getMap();
		}
		if(mapSObjectField.containsKey(fieldAPINameLower)) {
			isEncrypted = mapSObjectField.get(fieldAPINameLower).getDescribe().getType() == Schema.DisplayType.ENCRYPTEDSTRING ? true : false;
		}
		return isEncrypted;      
	}

	/**
	 * method to fetch field label based on field API and object name 
	 */
	public static String fetchFieldLabel(String fieldAPIName, String sObjectName, Boolean doGlobalDescribe) {
		String fieldLabel = fieldAPIName;
		String fieldAPINameLower = fieldAPIName.toLowerCase();
		String fieldAPINameSuffixed = fieldAPINameLower + TimelineProperties.ID_SUFFIX;
		if(String.isEmpty(fieldAPINameLower) || String.isEmpty(sObjectName))  {
			return fieldLabel;
		}
		if(!mapSObjectField.containsKey(fieldAPINameLower) && !mapSObjectField.containsKey(fieldAPINameSuffixed)) {
			mapSObjectField = SystemUtilities.getSobjectDescribe(sObjectName, doGlobalDescribe).fields.getMap();
		}
		fieldLabel = mapSObjectField.containsKey(fieldAPINameLower) ? mapSObjectField.get(fieldAPINameLower).getDescribe().getLabel() : 
					 mapSObjectField.containsKey(fieldAPINameSuffixed) ? mapSObjectField.get(fieldAPINameSuffixed).getDescribe().getLabel() : 
					 fieldAPINameLower;
		return fieldLabel;
	}
	
	/**
	 * method to fetch value dynamically based on sobject instance and fieldAPI passed in parameter. the Field API can be value traversing accross 
	 * parent objects
	 */
	public static object fetchFieldValue (Sobject sobjRec, String fieldApi) {
		Object returnValue;
		Sobject sobj = sobjRec.clone(true, true, true, true);
		String sobjFieldApi = fieldApi;

		while (sobjFieldApi.contains('.')) {
			List<String> lstSobjFields = sobjFieldApi.split('\\.', 2);
			sobj = sobj.getSobject(lstSobjFields[0]);
			sobjFieldApi = lstSobjFields[1];
		}
		if(sobj != null) {
			returnValue = sobj.get(sobjFieldApi);
		}

		return returnValue;
	}
	/**
	 * method to populate field values in formatted string e.g. This {0} is a formmated {1} string. The {0} and {1} will be replaced with field values 
	 */
	public static String populateFormattedString (String formattedString, Sobject sobjRec, List<String> lstFieldApis, Map<String, Object> mapMethodParams) {
		String fieldMergedString ;
		if(mapMethodParams == null) mapMethodParams = new Map<String, Object>();

		List<String> lstFieldValues = new List<String>();

		String dataType = mapMethodParams.containsKey(TimelineProperties.KEY_FIELDDATATYPE) ? (string) mapMethodParams.get(TimelineProperties.KEY_FIELDDATATYPE) : '';
	
		for(String fieldApi : lstFieldApis) {
			Object fieldValue = fetchFieldValue(sobjRec, fieldApi);
			String strFieldValue;
			
			if(fieldValue instanceOf Date) {
				strFieldValue = ((Date)fieldValue).format();
			}
			else if(fieldValue instanceOf DateTime) {
				strFieldValue = ((DateTime)fieldValue).format();
			}
			else if(fieldValue instanceOf Time) {
				strFieldValue = DateTime.newInstance(System.Today(), (Time)fieldValue).format('hh:mm:ss a');
			}
			else if(fieldValue instanceOf Decimal) {
				strFieldValue = String.valueOf(fieldValue).contains('.') && mapMethodParams.containsKey(TimelineProperties.KEY_DECIMALSCALE) ? 
									String.valueOf(((Decimal)fieldValue).setScale((Integer) mapMethodParams.get(TimelineProperties.KEY_DECIMALSCALE)) ) : 
									String.valueOf(fieldValue);
			}
			else  {
				if(fieldValue == null) {
					fieldValue = '';
				}
				strFieldValue = String.valueOf(fieldValue);

				if(String.isNotBlank(strFieldValue) && strFieldValue.remove('.').isNumeric() ) {
					strFieldValue = mapMethodParams.containsKey(TimelineProperties.KEY_DECIMALSCALE) ? 
											String.valueOf((Decimal.valueOf(strFieldValue)).setScale( (Integer) mapMethodParams.get(TimelineProperties.KEY_DECIMALSCALE)) ) : 
											String.valueOf(fieldValue);

					if(mapMethodParams.containsKey(TimelineProperties.KEY_RECCURRENCY)) {
						strFieldValue = mapMethodParams.get(TimelineProperties.KEY_RECCURRENCY) + ' ' +  strFieldValue;
					} 
				} 
			}

			lstFieldValues.add(strFieldValue);
		}

		fieldMergedString = String.format(formattedString, lstFieldValues);

		return fieldMergedString;
	}

	/**
	 * builds html <a> tag based on parameter passed 
	 */
	public static String buildRecordLinkString(String recordId, String labelStr) {
		return String.format('<a href="/{0}">{1}</a>', new List<String> { recordId, labelStr });
	}
}