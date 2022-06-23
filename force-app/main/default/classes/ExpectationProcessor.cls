public virtual class ExpectationProcessor {


    public virtual List<ExpectationProcess__c> getExpectationProcesses(string objectName){
        List<ExpectationProcess__c> expProcesses = new List<ExpectationProcess__c>();
        //TODO - What all does this need to return? Should the Child object be returned too or should I get them only if criteria is met?
        expProcesses = [SELECT Id, FilterCriteria__c, MustCompleteInOrder__c, ContinueWhenNotMet__c,
                        (SELECT Id, Name, Sequence__c, CriteriaToMeet__c, ExpectedTime__c, Measurement__c, StartWhen__c FROM Expectations__r)
                        FROM ExpectationProcess__c
                        WHERE Active__c = true AND ObjectType__c = :objectName];
        
        return expProcesses;
    }  

    /**
     * @description - the method to create the expectations related to the object
     * @returns - the list of the Expectations to be created
     */
    public virtual List<ExpectationRecord__c> SetExpectations(Id parentId, DateTime parentCreateDate, DateTime parentLastModDate, List<Expectation__c> exps){
        List<ExpectationRecord__c> expRecs = new List<ExpectationRecord__c>();
        for(Expectation__c exp : exps){
            ExpectationRecord__c expRec = new ExpectationRecord__c();
            expRec.RelatedRecordId__c = parentId;
            expRec.Expectation__c = exp.ExpectationProcess__c;
        }
        return expRecs;
    }
}