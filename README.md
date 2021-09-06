# What is timeline-component-lwc?
This post will cover some technical, functional aspects of the component. There are some limitations as well as planned enhancements mentioned below. 

# How to configure and use?
The component can be added to Lightning Record pages to show history for the record in context or record related to it. The component needs no configuration by default, just drag and drop like other OOB components and you are good to go. You can always customize the component by providing additional 'Timeline Configuration' details. Please visit the link below if you don't want to figure it out on your own. 
https://kshitijlawate.com/salesforce-record-history-in-timeline-view-using-a-custom-lightning-web-component-new-managed-package-version/

# Technical Aspects
1. It is built with combination of Apex and Lightning Web Components.
2. Apex Code takes care of fetching the history data, defining & building wrapper structure to show on UI.
3. Object and Field level access control is handled in the apex code. If the logged in user does not have access to object or field, the component won't show it. 
4. Search functionality is handled completely on client side through JavaScript. There are Search tag arrays built into wrapper to filter records based on User input in text field. 
5. The Apex Code is using few reusable methods from SystemUtilities apex class. These can be used outside the scope of this component. 


# Limitations
1. Percent fields are shown without Percent signs. They will show up just like normal number fields. 
2. For Encrypted fields, only the "change" event is shown, not the actual or masked value.
3. The data does not auto-refresh if the component is open and data changes. The refresh button is available for force manual refresh. 
