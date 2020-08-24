# What is timeline-component-lwc?
This post will cover some technical, functional aspects of the component. There are some limitations as well as planned enhancements mentioned below. 

# How to configure and use?
The component can be added to Lightning Record pages to show history for the record in context or record related to it. There is some configuration required in app builder when it is added to the page. Here is the video that explains how to do it, https://youtu.be/xWJqyk0Yu3k.

# Technical Aspects
1. It is built with combination of Apex and Lightning Web Components.
2. Apex Code takes care of fetching the history data, defining & building wrapper structure to show on UI.
3. Object and Field level access control is handled in the apex code. If the logged in user does not have access to object or field, the component won't show it. 
4. Search functionality is handled completely on client side through JavaScript. There are Search tag arrays built into wrapper to filter records based on User input in text field. 
5. The Apex Code is using few reusable methods from SystemUtilities apex class. These can be used outside the scope of this component. 
6. Writing Test Class for classes centered around OOB history objects is difficult. In order to cover the apex class written with this component, the test classes will need to have 'SeeAllData' set to True. Hence, for your specific org, you can create a test record and fetch that in the test class which is provided in the repository. 

# Limitations
1. Percent, Currency fields are shown without Percent or Currency signs.
2. For Encrypted fields, only the "change" event is shown, not the actual or masked value.
3. The data does not auto-refresh if the component is open and data changes. The refresh button is available for force manual refresh. 

# Planned Enhancements
1. Improve Search Mechanism; move away from linear search, more towards dictionary like approach.
2. Move the configuration to Custom metadata.
3. Add additional filters with an option for configuring default filters
