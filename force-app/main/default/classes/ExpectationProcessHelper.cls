public without sharing class ExpectationProcessHelper {        
	private static final String STATUS_UPCOMING = 'Upcoming';
	private static final String STATUS_OVERDUE = 'Overdue';
	private static final String STATUS_COMPLETE = 'Completed';
	private static final String STATUS_BYPASSED = 'Bypassed';

    @TestVisible
    private static string objectName;


    /**
     * @description : This is the main method to do all the expectation objects logic
     * @param objRecords 
     */
    public static void applyExpectations(List<SObject> objRecords){
        if (objRecords.size() == 0){
            return;            
        }
		objectName = objRecords.get(0).getSObjectType().getDescribe().getName(); 
        system.debug('ObjectName: ' + objectName);
        //these are the expectation records that should be related to the record
        List<ExpectationRecord__c> newExpRecs = getExpectationRecordsOfProcesses(objRecords);
        //don't create expectation records if they already exist
        List<ExpectationRecord__c> dedupedExpRecs = dedupeExpectationRecords(objRecords, newExpRecs);
        //evaluate and upsert the records
        evaluateAndUpsertExpectationRecords(objRecords, dedupedExpRecs);
    }

    /**
     * @description : setup the ExpectationRecords that should be related to the object based on the ExpectationProcess evaluation
     * these records may have been created already by will be removed later in dedupe
     * @param objRecs 
     * @return  `List<ExpectationRecord__c>`
     */
    @TestVisible
    private static List<ExpectationRecord__c> getExpectationRecordsOfProcesses(List<SObject> objRecs){         
        //these are all of the expectations that these objRecs should have
        List<ExpectationProcess__c> expProcesses = getExpectationProcesses();
        Map<Id, List<Expectation__c>> objAndExpsMap = new Map<Id, List<Expectation__c>>();
        for(SObject currObj : objRecs){
            for(ExpectationProcess__c currEP : expProcesses){
                //if the ExpProcess meets the criteria relate the Expectations needed for that record
                //there can be more than 1 ExpectationProcess
                //system.debug('Current ExpProcess: ' + currEP);
                if(currEP.Active__c == true && parseCriteria(currObj, currEP.FilterCriteria__c)){  
                    //system.debug('ProcessCriteria is true!' + currObj.Id + ' Expectations: ' + currEP.Expectations__r.size());                                          
                    List<Expectation__c> exps = new List<Expectation__c>();
                    exps.addAll(currEP.Expectations__r);
                    if(objAndExpsMap.containsKey(currObj.Id)){  
                        objAndExpsMap.get(currObj.Id).addAll(exps);
                    }else {
                        objAndExpsMap.put(currObj.Id, exps);
                    }                
                }
            }
        }
        List<ExpectationRecord__c> newExpectationRecs = new List<ExpectationRecord__c>();
        for(SObject obj : objRecs){
            if(objAndExpsMap.containsKey(obj.Id)){
                List<Expectation__c> objExpectations = objAndExpsMap.get(obj.Id);
                //this only setsup new records it does not insert them
                List<ExpectationRecord__c> newExpRecs = setupExpectationRecord(obj, objExpectations);
                newExpectationRecs.addAll(newExpRecs);
            }
        }
        return newExpectationRecs;
    }

    /**
     * @description : compares pre-existing ExpectationRecords preventing ones already created from being duplicated
     * and adding ExpectationsRecords of other ExpProcesses
     * @param objRecs 
     * @param allExpRecs 
     * @return  `List<ExpectationRecord__c>`
     */
    @TestVisible
    private static List<ExpectationRecord__c> dedupeExpectationRecords(List<SObject> objRecs, List<ExpectationRecord__c> allExpRecs){
        //get the expRecs that already exist regardless of if the process is active or inactive
        List<ExpectationRecord__c> existingExpRecs = getExistingExpectationRecords(objRecs);
        if(!existingExpRecs.isEmpty()){
            for(ExpectationRecord__c existingRec : existingExpRecs){                
                Boolean removed = false;  
                for (Integer i = 0; i < allExpRecs.size(); i++) {
                    if(!removed && allExpRecs[i].RelatedRecordId__c == existingRec.RelatedRecordId__c && 
                            allExpRecs[i].Expectation__c == existingRec.Expectation__c){
                        allExpRecs.remove(i);
                        removed = true;
                    }                    
                }
            }
            allExpRecs.addAll(existingExpRecs);
        }        
        return allExpRecs;
    }   

    /**
     * @description : query for ExpectationRecords related to the objects
     * @param objRecs 
     * @return  `List<ExpectationRecord__c>`
     */
    private static List<ExpectationRecord__c> getExistingExpectationRecords(List<SObject> objRecs){
        Map<Id, SObject> objIdMap = new Map<Id, SObject>(objRecs);
        DateTime dateForQuery = datetime.now();
        for(SObject obj : objRecs){
            DateTime objCreatedDate = (DateTime)obj.get('CreatedDate');
            if(objCreatedDate < dateForQuery){
                dateForQuery = objCreatedDate;
            }
        }
        //get the expRecs that already exist regardless of if the process is active or inactive
        List<ExpectationRecord__c> existingExpRecs = [SELECT Id, Name, CompletionTime__c, DueBy__c, Expectation__c, Expectation__r.Name, 
                                                        RelatedRecordId__c, Sequence__c, StartTime__c, Status__c
                                                      FROM ExpectationRecord__c 
                                                      WHERE RelatedRecordId__c =: objIdMap.KeySet() AND CreatedDate >= :dateForQuery];
        return existingExpRecs;
    }

    /**
     * @description : set the current ExpectationRecord based on criteria evaluation
     * fields set: Status__c, CompletionTime__c
     * @param objRecs 
     * @param expRecs 
     */
    public static void evaluateAndUpsertExpectationRecords(List<SObject> objRecs, List<ExpectationRecord__c> expRecs){ 
        Map<Id, SObject> objMap = new Map<Id, SObject>(objRecs);
        Set<Id> expIdSet = new Set<Id>();       
        for(ExpectationRecord__c expRec : expRecs){
            expIdSet.add(expRec.Expectation__c);
        }
        List<Expectation__c> expectations = getExpectationsById(expIdSet);
        Map<Id, Expectation__c> expMap = new Map<Id, Expectation__c>(expectations);
        //this is a map of the relatedRecordId and their different ExpectationProcesses
        Map<Id, Set<Id>> objIdExpProcessIdMap = new Map<Id, Set<Id>>();
        for(ExpectationRecord__c expRec : expRecs){
            Expectation__c exp = expMap.get(expRec.Expectation__c);
            if(objIdExpProcessIdMap.containsKey(expRec.RelatedRecordId__c)){
                objIdExpProcessIdMap.get(expRec.RelatedRecordId__c).add(exp.ExpectationProcess__c);
            }else{
                objIdExpProcessIdMap.put(expRec.RelatedRecordId__c, new Set<Id>{exp.ExpectationProcess__c});
            }
        }

        for(Id recordId : objIdExpProcessIdMap.keySet()){
            Set<Id> processIdsOfRecord = objIdExpProcessIdMap.get(recordId);
            //we're going to evaluate the expectation records related to the object and it's ExpectationProcess
            for (Id expProcessId : processIdsOfRecord) {  
                Map<Id, Expectation__c> expsInProcess = new Map<Id, Expectation__c>();
                List<ExpectationRecord__c> expRecsInProcess = new List<ExpectationRecord__c>(); 
                //the the expecations related to this process
                for (Id expId : expMap.keySet()) {
                    if(expMap.containsKey(expId)){
                        Expectation__c exp = expMap.get(expId);
                        expsInProcess.put(exp.Id, exp);
                    }
                }

                //get the expRecs for this ExpProcess and this object         
                for (ExpectationRecord__c expRec : expRecs) {
                    if(expRec.RelatedRecordId__c == recordId && expsInProcess.containsKey(expRec.Expectation__c)){
                        expRecsInProcess.add(expRec);
                    }
                }  
                //evaluate the expRecs for this ExpProcess
                if(!expRecsInProcess.isEmpty()){
                    SObject objToEval = objMap.get(recordId);
                    evaluateExpectationRecordsOfProcess(objToEval, expsInProcess, expRecsInProcess);
                }
            }
        } 
        
        //upsert the expRecs
        Database.UpsertResult[] upsertResults = Database.upsert(expRecs, false);
        ErrorLogger.logUpsertErrors(upsertResults, 'ExpectationProcessHelper'); 
    }

    @TestVisible
    private static void evaluateExpectationRecordsOfProcess(SObject obj, Map<Id, Expectation__c> expMap, List<ExpectationRecord__c> expRecords){
        //order the recs to evaluate highest to lowest and evaluate
        Map<Decimal, ExpectationRecord__c> expRecsMap = new Map<Decimal, ExpectationRecord__c>();
        for(ExpectationRecord__c expRec : expRecords){
            //only evaluate the incomplete records
            if(expRec.Status__c != STATUS_COMPLETE && expRec.Status__c != STATUS_BYPASSED){
                expRecsMap.put(expRec.Sequence__c, expRec);
            }
        }
        List<Decimal> expSeq = new List<Decimal>(expRecsMap.keySet());
        expSeq.sort(); 
        Decimal criteriaMetOnSeqKey = 0;
        //only set the record that meets criteria
        for (Decimal seqKey : expSeq) {         
            ExpectationRecord__c expRec = expRecsMap.get(seqKey);
            String expCriteria = expMap.get(expRec.Expectation__c).CriteriaToMeet__c;
            Boolean criteriaMet = parseCriteria(obj, expCriteria);
            system.debug('SEQUENCE: ' + seqKey + ' Criteria Met?: ' + criteriaMet);
            if(criteriaMet){
                expRec.CompletionTime__c = datetime.now();
                expRec.Status__c = STATUS_COMPLETE;
                if(seqKey > criteriaMetOnSeqKey){
                    criteriaMetOnSeqKey = seqKey;
                }
            }        
        }
        
        //set the other expRecs
        for (Decimal seqKey : expSeq) {         
            ExpectationRecord__c expRec = expRecsMap.get(seqKey);
            Expectation__c exp = expMap.get(expRec.Expectation__c);
            if(expRec.Status__c != STATUS_COMPLETE){
                if(seqKey < criteriaMetOnSeqKey){
                    if(exp.ExpectationProcess__r.MustCompleteInOrder__c == true /*&& UserInfo.getProfileId() != system.label.System_Admin_Profile_ID*/){
                        expRec.addError('The Expectations must be completed in sequence.');                
                        //if(expRec.Expectation__r.ContinueWhenNotMet__c && expRec.Status__c = STATUS_OVERDUE) {
                            //what do we do? Make the complete the expectation prior to other edits?  Bypass all the record?
                            //addError('');
                        //}
                    }
                    expRec.Status__c = STATUS_BYPASSED;
                    expRec.CompletionTime__c = datetime.now();
                }
                if(seqKey > criteriaMetOnSeqKey){
                    if(exp.StartWhen__c == 'Previous Expectation Completed'){
                        expRec.StartTime__c = datetime.now();
                        expRec.DueBy__c = setDueBy(expRec.StartTime__c, exp.Measurement__c, exp.ExpectedTime__c);
                    }else{
                        expRec.Status__c = expRec.DueBy__c < datetime.now() ? STATUS_OVERDUE : STATUS_UPCOMING;                     
                    }
                }
            }     
        }

    }

    /**
     * @description : query for active ExpectationProcesses__c of the objectName
     * @return  `List<ExpectationProcess__c>`
     * @exception 
     */
    @TestVisible
    private static List<ExpectationProcess__c> getExpectationProcesses(){
        if(objectName == null){           
            throw new ExpectationProcessHelperException('objectName must be set in class!');
        }
        //get active exp process records 
        List<ExpectationProcess__c> expProcesses = [SELECT Id, FilterCriteria__c, MustCompleteInOrder__c, ContinueWhenNotMet__c, Active__c,
                                                          (SELECT Id, CriteriaToMeet__c, Name, ExpectedTime__c, Measurement__c,Sequence__c,StartWhen__c
                                                            FROM Expectations__r)
                                                    FROM ExpectationProcess__c
                                                    WHERE ObjectType__c = :objectName AND Active__c = true];
        return expProcesses;
    } 

    /**
     * @description : query for Expectation_c records by their Id
     * @param expIds 
     * @return  `List<Expectation__c>`
     */
    @TestVisible
    private static List<Expectation__c> getExpectationsById(Set<Id> expIds){
        return [SELECT Id, ActivationDate__c, CriteriaToMeet__c, Name, ExpectedTime__c, Measurement__c,Sequence__c, StartWhen__c,
                    ExpectationProcess__c, ExpectationProcess__r.MustCompleteInOrder__c, ExpectationProcess__r.ContinueWhenNotMet__c
                FROM Expectation__c 
                WHERE Id = :expIds
                ORDER BY Sequence__c desc];
    }
    
    /**
     * @description : intitialize ExpectationRecord fields based on the related record and Expectation
     * NOTE:  this does not insert
     * @param obj 
     * @param expList 
     * @return  `List<ExpectationRecord__c>`
     */
    @TestVisible
    private static List<ExpectationRecord__c> setupExpectationRecord(SObject obj, List<Expectation__c> expList){
        //ECRM-6096: This method is used to create expectation records given a map of records to respective lists of expectations.
        //This method requires that the following fields be queried (for a Parts Request):
        //Parts_Request__c obj = [SELECT Id, OwnerId, Name, CreatedDate FROM Parts_Request__c Limit 1];
        //List<Expectation__c> expList = [SELECT Id, Sequence__c, StartWhen__c, Measurement__c, ExpectedTime__c, Name  FROM Expectation__c];
        List<ExpectationRecord__c> newERList = new List<ExpectationRecord__c>();        
        for(Expectation__c currExp : expList){
            ExpectationRecord__c newER = new ExpectationRecord__c(
                OwnerId = (String)obj.get('OwnerId'),
                RelatedRecordId__c = obj.Id,
                Expectation__c = currExp.Id,
                Name = currExp.Name,
                Sequence__c = currExp.Sequence__c,
                Status__c = 'Upcoming'
            );          
            //Set Start Time
            if(currExp.StartWhen__c == 'Process Creation'){
                newER.StartTime__c = DateTime.Now();
            }
            else if(currExp.StartWhen__c == 'Record Creation'){
                newER.StartTime__c = (DateTime)obj.get('CreatedDate');
            }else if (currExp.Sequence__c == 1){   
                //StartWhen = 'Previous Expectation Completed' must have first seq start time set             
                newER.StartTime__c = DateTime.Now();
            }
            //Set Due By
            if(newER.StartTime__c != null){
                newER.DueBy__c = setDueBy(newER.StartTime__c, currExp.Measurement__c, currExp.ExpectedTime__c); 
            }
            //Set lookup on new Expectation Record - the lookup name MUST BE the same as the object API Name
            newER.put(obj.getSObjectType().getDescribe().getName(), obj.Id);
            newERList.add(newER);
        }
        return newERList;
    }

    /**
     * @description : set the DueBy field of the ExpectationRecord
     * @param startDateTime 
     * @param measurement 
     * @param expTime 
     * @return  `DateTime`
     */
    private static DateTime setDueBy(DateTime startDateTime, string measurement, Decimal expTime){
        DateTime dueBy = null;
        if(startDateTime != null && measurement != Null && expTime != Null){
            if(measurement == 'Days'){
                dueBy = startDateTime.addDays(Integer.ValueOf(expTime));
            }
            else if(measurement == 'Hours'){
                dueBy = startDateTime.addHours(Integer.ValueOf(expTime));
            }
            else if(measurement == 'Minutes'){
                dueBy = startDateTime.addMinutes(Integer.ValueOf(expTime));
            }
        } 
        return dueBy;  
    }
    
    /**
     * @description : evaluate criteria for the relayed object
     * @param objRec 
     * @param strCriteria 
     * @return  `Boolean`
     */
    @TestVisible
    private static Boolean parseCriteria(SObject objRec, string strCriteria){
        return FilterCriteriaEngine.parseCriteria(objRec, strCriteria);
    }

    public class ExpectationProcessHelperException extends Exception {

    }

}