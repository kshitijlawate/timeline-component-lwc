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
Test class for SystemUtilities
*/
@isTest
public with sharing class SystemUtilitiesTest 
{
    @istest
    public static void systemUtilitiesTest() 
    {
        User currentUser = [SELECT Id, Profile.Name, CreatedBy.Profile.CreatedDate, Name, MobilePhone 
                                FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];

        system.assertEquals(currentUser.Profile.Name, SystemUtilities.fetchFieldValue(currentUser, 'Profile.Name'));
        system.assertEquals(currentUser.Id, SystemUtilities.fetchFieldValue(currentUser, 'Id'));
        system.assertEquals(currentUser.CreatedBy.Profile.CreatedDate, SystemUtilities.fetchFieldValue(currentUser, 'CreatedBy.Profile.CreatedDate'));

        List<String> lstFieldApis = new List<String> 
        {
            'Name', 'Profile.Name', 'CreatedBy.Profile.CreatedDate', 'MobilePhone'
        };
        String formattedString = 'The current user\'\'s name is {0} and his profile is {1} and was created on {2}. His mobile phone is {3}.';

        String fieldMergedString = SystemUtilities.populateFormattedString (formattedString, currentUser, lstFieldApis, 3);

        system.assert(fieldMergedString.contains(currentUser.Name));
        system.assert(fieldMergedString.contains(currentUser.Profile.Name));
    }
    @istest
    public static void sobjectDescribeTest() 
    {
        Schema.DisplayType dt = SystemUtilities.getFieldDisplayType('user', 'name', true);
        system.assertEquals(dt, Schema.DisplayType.String);

        Schema.DescribeSObjectResult objDescribe = SystemUtilities.getSobjectDescribe(new User(Id = UserInfo.getUserId()));
        System.assertEquals(User.SobjectType, objDescribe.getSobjectType());

    }
}