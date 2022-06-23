/*************************************************
* Class Name: ExpectationRecordRelatedListController 
* Author: Jonathan Habbick
* Date: 16-March-2022
* Requirement/Project Name: Vantage
* Requirement/Project Description: Controller for the expectationRecordRelatedListLWC. 
 * Revision History
 * Ver      Developer            Reference       Date        Description
 * 1.0      Jonathan Habbick     ECRM-6260       3/16/2022   Controller for the expectationRecordRelatedListLWC
*************************************************/
public with sharing class ExpectationRecordRelatedListController {
    
    //This method gets and evaluates all expectation records associated with the parent record
    @AuraEnabled
    public static List<ExpectationRecord__C> getExpectationRecords(Id recordId){
        
        //Get parent object for later expectation record evaluation
        SObjectType objType = recordId.getSObjectType();
        String fieldList = getObjFields(recordId);
        String queryString = 'SELECT ' + fieldList + ' FROM ' + String.ValueOf(objType) +  ' WHERE Id = \'' + String.ValueOf(recordId) + '\' LIMIT 1';
        SObject obj = Database.query(queryString); 

        //Get all related expectation records
        List<ExpectationRecord__C> relatedERs = new List<ExpectationRecord__C>();
        
        try{
            relatedERs.addAll([
                SELECT Id, Name,StartTime__c, CompletionTime__c,Status__c, /*Parts_Request__c,*/ Lead__c, Sequence__c, ExpectedMinutes__c, RelatedRecordId__c, DueBy__c, Expectation__c 
                FROM ExpectationRecord__C WHERE RelatedRecordId__c =: obj.Id Order by Sequence__c ASC]);
        }catch(Exception e){
            System.debug('ERROR=> ' + e);
        }
        
        //Evaluate all related expectation records
        List<SObject> objList = new List<SObject>{obj};
        try{
            ExpectationProcessHelper.evaluateAndUpsertExpectationRecords(objList, relatedERs);

        }catch(Exception e){
            System.debug('ERROR=> ' + e);
        }
        
        return relatedERs;
    }

    //This helper method retrieves all of the field names for a given Id and returns them as a comma seperated string
    //Used in the getExpectationRecords method to get parent object fields for query
    @TestVisible
    private static string getObjFields(Id recordId){
        String fieldList;
        if(recordId != null){
            try{
                //Get fields from sObject type associated with Id
                SObjectType objType = recordId.getSObjectType();
                Map<String,Schema.SObjectField> mfields = objType.getDescribe().fields.getMap();

                //put fields into a string for return
                for(String s : mfields.keySet()){
                    if(String.isEmpty(fieldList)){
                        fieldList = String.valueOf(mfields.get(s));
                    }
                    else{
                        fieldList = fieldList +', '+ String.valueOf(mfields.get(s));

                    }
                }
                
            }catch(Exception e){
                System.debug('getObjFields ERROR => ' + e);
                throw new AuraHandledException(e.getMessage());
            }
                        
        }
        return fieldList;
    }

    //This helper method retrieves all of the field names for a given Id and returns them as a list of strings
    //Used in the expectationRecordRelatesList method to get parent object fields for getRecord method
    @AuraEnabled(cacheable=true)
    public static List<String> getObjFieldsForLWC(Id recordId){
        List<String> sObjectDetailsList = new List<String>();
        if(recordId != null){

            try{
                //Get fields from sObject type associated with Id
                SObjectType objType = recordId.getSObjectType();
                Map<String,Schema.SObjectField> mfields = objType.getDescribe().fields.getMap();

                //put fields into a list for return
                for(String s : mfields.keySet()){
                    sObjectDetailsList.add(String.valueOf(mfields.get(s)));
                }
            }catch(Exception e){
                System.debug('getObjFields ERROR => ' + e);
                throw new AuraHandledException(e.getMessage());
            }
                        
        }
        else{
            sObjectDetailsList.add('Id');
        }
        return sObjectDetailsList;
    }
}