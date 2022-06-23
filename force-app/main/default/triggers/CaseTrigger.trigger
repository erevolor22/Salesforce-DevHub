trigger CaseTrigger on Case (after delete, after insert, after undelete, after update, before delete, before insert, before update) {
    
    //Common_Settings__c cs = Common_Settings__c.getInstance('Skip Triggers');
    
    //boolean skipTrigger = cs.Skip_Triggers__c;
    
    CaseTriggerHandler handler = new CaseTriggerHandler(Trigger.isExecuting, Trigger.size);  
    if(Trigger.isInsert && Trigger.isBefore){  
        handler.OnBeforeInsert(Trigger.new);  
    }  
    
    else if(Trigger.isUpdate && Trigger.isBefore){  
        handler.OnBeforeUpdate(Trigger.old, Trigger.new, Trigger.newMap, Trigger.oldMap);  
    }  
    
    else if(Trigger.isInsert && Trigger.isAfter){  
        handler.OnAfterInsert(Trigger.new);  
        
        
    }
    
    else if(Trigger.isUpdate && Trigger.isAfter){
        handler.OnAfterUpdate(Trigger.old, Trigger.new, Trigger.newMap);
    }
    
}