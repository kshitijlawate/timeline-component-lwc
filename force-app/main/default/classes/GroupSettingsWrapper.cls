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
public class GroupSettingsWrapper {
    public String objectFieldAPIName;
    public String subSectionTitle;
    public List<String> lstSubSectionFields;
    public String withNewValueOnly;
    public String withNewOldValue;
    public String withNoValue;
    public String withOldValueOnly;
    public List<String> lstContentFields = new List<String> ();
    //constructor that defines field API name in parameter
    public GroupSettingsWrapper(String fieldAPIName) {
        this.objectFieldAPIName = fieldAPIName;
        lstContentFields = new List<String> {'Field', 'OldValue', 'NewValue' }; 
    }
    //method for adding title for sub section template and its merge fields 
    public GroupSettingsWrapper addSubSectionTemplate(String subSectionTitle, List<String> lstSubSectionFields) {
        this.subSectionTitle = subSectionTitle;
        this.lstSubSectionFields = lstSubSectionFields;
        return this;
    }
    //method for adding string templates for content strings with 3 different scenarios. 
    public GroupSettingsWrapper addFieldMappingTemplate(String withNewOldValue, String withNewValueOnly, String withNoValue, String withOldValueOnly) {
        this.withNewOldValue = withNewOldValue;
        this.withNewValueOnly = withNewValueOnly;
        this.withNoValue = withNoValue;
        this.withOldValueOnly = withOldValueOnly;
        return this;
    }
}