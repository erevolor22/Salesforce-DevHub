/*************************************************
* Class Name: CaseTriggerHandler
* Author: 
* Date: 
* Requirement/Project Name: 
* Requirement/Project Description: 
*************************************************/

public with sharing class CaseTriggerHandler {
    private boolean m_isExecuting = false;
    private integer BatchSize = 0;
    public static Boolean isFirstTime = true;
    public Id npsRecordTypeId = Schema.SObjectType.case.getRecordTypeInfosByName().get('NPS').getRecordTypeId();
    public Id siteBuiltNpsRecordTypeId = Schema.SObjectType.case.getRecordTypeInfosByName().get('NPS Site Built').getRecordTypeId();
    //public Id ServiceInquiryRecordTypeId = Schema.SObjectType.case.getRecordTypeInfosByName().get('Service Inquiry').getRecordTypeId();
    public static boolean isRecursive = true;
    public static boolean skipAfterUpdate = false;

    public CaseTriggerHandler(boolean isExecuting, integer size){
        m_isExecuting = isExecuting;
        BatchSize = size;
    }

    public void OnBeforeInsert(Case[] newCase){

        //List to hold all new account IDs
        List<ID> accountIDs = new List<ID>();
        List<Case> casesWithAccounts = new List<Case>();
        Set<Id> assetIds = new Set<Id>();
        Set<Id> accountContactIds = New Set<Id>();
        Id UserProfileId = UserInfo.getProfileId();
        Id RecordTypeId = Schema.SObjectType.account.getRecordTypeInfosByName().get('Customer').getRecordTypeId();

        //Iterate through each new case and determine if an account was associated
        for(Case f : newCase){
            if(f.AccountId != null) {
                accountIDs.add(f.AccountId);
                //Add the case to the list of new cases that came in that have accounts associated
                casesWithAccounts.add(f);
                accountContactIds.add(f.AccountId);
            }
            if(f.assetId != null){
                assetIds.add(f.assetId);
            }

        }

        if(accountContactIds.size() > 0){
            //get a list of contacts associated to these accounts in our set
            List<Contact> contactsToUpdate = New List<Contact>([Select Id, AccountId FROM Contact WHERE AccountId IN :accountContactIds]);
            Map<Id,Id> accountAndContactToUpdate = New Map<Id,Id>();
            for(Contact c : contactsToUpdate){

                accountAndContactToUpdate.put(c.AccountId, c.Id);
            }

            for(case cs : newCase){

                //associate the contact id
                if(accountAndContactToUpdate.containsKey(cs.AccountId)){
                    if(cs.ContactId==null){
                        cs.ContactId = accountAndContactToUpdate.get(cs.AccountId);
                    }
                }
            }
        }
    }
    
    public void OnBeforeUpdate(Case[] oldCases, Case[] updatedCases, Map<ID, Case> newCasemap, Map<id,Case> oldCaseMap){
        String currentUserProfileName = CommonSingletonClass.getProfileNameMap().get(UserInfo.getProfileId());

        if(currentUserProfileName != 'System Administrator'){
            Map<Id, Case> ownerIDToCase = new Map<Id, Case>();
            
            for(Case nc : newCaseMap.values()){
                if(nc.Status == 'Closed' && (oldCaseMap.get(nc.Id).Status != 'Closed')){
                    ownerIDToCase.put(nc.OwnerID, nc);
                }
            }

            for(User owner : [SELECT Id, Profile.Name FROM User WHERE Id IN: ownerIDToCase.keySet()]){
                if(currentUserProfileName == 'Contract Manager'){
                    ownerIDToCase.get(owner.Id).addError('You cannot do that since you are a Contract Manager');
                }
            }
        }
    }
    
    public void OnAfterUpdate(Case[] oldCases, Case[] updatedCases, Map<ID, Case> newCaseMap){{}}
    
    public void OnAfterInsert(Case[] newCase){{}}
}