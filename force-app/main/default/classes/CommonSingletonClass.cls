/*************************************************************************************************
 * Class Name                       : 
 * Author                           : 
 * Date                             : 
 * Requirement/Project Name         : This is common class based on singleton concept, it will reduce SOQL query for some of the common 
 * 									: functionlity like getting queue id record type id by passing name and in one transcation will query 
 * 									: only once and easy to use these method from any where.
 
 *************************************************************************************************/ 

public class CommonSingletonClass {
    
    private static Map<String,Id> caseQueueMap = new Map<String,Id>();
    private static Map<String,Id> leadQueueMap = new Map<String,Id>();
    private static Map<String,Id> recordTypeMap = new Map<String,Id>();
    private static Map<String,Id> profileIdMap = new Map<String,Id>();
    private static Map<Id, String> profileNameMap = new Map<Id, String>();
    
    //Call this method and pass API name of Case queue and it will return Id of queue
    public static Map<String,Id> getCaseQueueMap(){
        
        if(caseQueueMap.size() == 0){
            List<Group> caseQueueList = [select id,DeveloperName from Group where id IN (select queueId from QueueSobject where SobjectType = 'Case')];
            for(Group grp:caseQueueList){
            	caseQueueMap.put(grp.DeveloperName,grp.id);
        	}
            return caseQueueMap;
        }else{
            return caseQueueMap;
        }
        
    }
    
    //Call this method and pass API name of Lead queue and it will return Id of queue   
    public static Map<String,Id> getLeadQueueMap(){
        
        if(leadQueueMap.size() == 0){
            List<Group> leadQueueList = [select id,DeveloperName from Group where id IN (select queueId from QueueSobject where SobjectType = 'Lead')];
            for(Group grp:leadQueueList){
            	leadQueueMap.put(grp.DeveloperName,grp.id);
        	}
            return leadQueueMap;
        }else{
            return leadQueueMap;
        }
        
    }
    
    //Call this method and pass <ObjectAPIName:RecordTypeDeveloperName> as key to get Id from Map e.g. "Case:NPS" and it will return Id of recordtype
    public static Map<String,Id> getRecordTypeMap(){
        
        if(recordTypeMap.size() == 0){
            List<RecordType> recordTypeList = [SELECT DeveloperName,Id,SobjectType FROM RecordType where isactive = true];
            for(RecordType RT:recordTypeList){            
            	recordTypeMap.put(RT.SobjectType+':'+RT.DeveloperName,RT.id);
            }
            return recordTypeMap;
            
        }else{
            return recordTypeMap;
        }
        
    }
    
    //Call this method and pass profile as key to get profile Id from Map 
    public static Map<String,Id> getProfileIdMap(){
        
        if(profileIdMap.size() == 0){
            List<Profile> profileList = [SELECT Name,Id FROM Profile];
            for(Profile prof:profileList){            
            	profileIdMap.put(prof.Name,prof.id);
            }
            return profileIdMap;
            
        }else{
            return profileIdMap;
        }
        
    }

    //call this method and pass the profile Id to get the profile name
    public static Map<Id, String> getProfileNameMap(){        
        if(profileNameMap.size() == 0){
            List<Profile> profileList = [SELECT Name,Id FROM Profile];
            for(Profile prof:profileList){            
            	profileNameMap.put(prof.id,prof.Name);
            }
            return profileNameMap;            
        }else{
            return profileNameMap;
        }
    } 

}