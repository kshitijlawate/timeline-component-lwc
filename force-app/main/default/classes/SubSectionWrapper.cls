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
Wrapper for Sub section, children to Section Wrapper
*/

public class SubSectionWrapper {
    @AuraEnabled public String subSectionTitle;
    @AuraEnabled public DateTime relativeDateTime;
    @AuraEnabled public DateTime actualDateTime;
    @AuraEnabled public String subSectionId; 
    
    
    @AuraEnabled public List<ContentWrapper> lstContentString;
    
    public SubSectionWrapper() { }
    
    public SubSectionWrapper(String subSectionId, String subSectionTitle, DateTime actualDateTime) {
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