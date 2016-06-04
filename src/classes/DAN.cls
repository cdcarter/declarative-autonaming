global class DAN {
    // core data types for the INameSpec interface
    global class NameSpecRequest {
        public String nameSpec;
        public Id objectId;
        public SObjectType objectType;
        global NameSpecRequest(){}
        public NameSpecRequest(NameRule rule, SObject obj) {
            this.nameSpec = rule.nameSpec; this.objectId = obj.Id; this.objectType = obj.getSObjectType();
        }
    }
    global class NameSpecResult {
        public String name;
        public Id objectId;
    }
    
    // core interface for naming implementations to implement
    global interface INameSpec {
        List<DAN.NameSpecResult> autoname(List<DAN.NameSpecRequest> reqs);
    }
    
    /* ***************************************************************
*  Trigger handler and test methods for use by deployed triggers
* *************************************************************** */
    
    private static Boolean triggerHandlerInvoked = false;
    private static Boolean inTrigger = false;
    
    // only exported method for triggers to use
    global static void handleAfterTrigger(List<SObject> objects) {
        if(!DAN.inTrigger){
            DAN.inTrigger = true;
            renameAndUpdate(objects);
            DAN.inTrigger = false;
            DAN.triggerHandlerInvoked = true;
        }
    }
    
    global static void testHandler(String objString) {
        Schema.SObjectType objType = Schema.getGlobalDescribe().get(objString);
        try {
            SObject testRecord = objType.newSObject(null,true);
            testRecord.put('Name','anythngbutthis');
            if(objString == 'Opportunity') {
                testRecord.put('StageName','Posted');
                testRecord.put('CloseDate',Date.today());
            }
            insert testRecord;
            system.assertNotEquals('anythingButThis',(String)testRecord.get('Name'));
        } catch (Exception e) {
            if(triggerHandlerInvoked) return; // throw away errors if the trigger ran.
            throw e;
        }
    }
    
    /* ***************************************************************
*  Rule Assignment and Renaming
* *************************************************************** */
    
    private static List<Database.SaveResult> renameAndUpdate(List<SObject> objects) {
        if(objects.size() > 0) {
            List<Database.SaveResult> retval = new List<Database.SaveResult>();
            List<NameRule> rules = getRules(objects[0].getSObjectType().getDescribe().getName());
            List<SObject> results = new List<SObject>();
            for(NameRule rule : rules) {
                results.addAll(getResults(rule,objects));
            }
            retval.addAll(Database.update(results));
            return retval;
        }
        return null;
    }
    
    private static List<NameRule> getRules(String objname) {
        return selectorWrapper([SELECT Id, DeveloperName,Label,Active__c, Name_Spec__c, NameSpec_Processor__c, Naming_Result_Field__c,Filter_Field__c,Filter_Value__c , Object__c FROM Autonaming_Rule__mdt WHERE Active__c = true AND Object__c = :objName]);
    }
    
    private static List<NameRule> selectorWrapper(List<Autonaming_Rule__mdt> mdts) {
        List<NameRule> result = new List<NameRule>();
        for(Autonaming_Rule__mdt rule : mdts) {
            result.add(new NameRule(rule));
        }
        return result;
    }
    
    /* ***************************************************************
*  Name processing dispatch and result handling
* *************************************************************** */
    
    private static List<SObject> getResults(NameRule rule,List<SObject> objs) {
        Type processorType = Type.forName(rule.nameSpecProcessor);
        INameSpec processor = (INameSpec)processorType.newInstance();
        List<NameSpecRequest> reqs = reqsFromObjects(rule,objs);
        List<NameSpecResult> processorResults = processor.autoname(reqs);
        
        SObjectType objType = Schema.getGlobalDescribe().get(rule.obj);
        List<SObject> result = new List<SObject>();
        for(NameSpecResult res : processorResults) {
            SObject obj = objType.newSObject();
            obj.put('Id', res.objectId);
            obj.put(rule.nameField, res.name);
            result.add(obj);
        }
        return result;
    }
    
    private static List<NameSpecRequest> reqsFromObjects(NameRule rule, List<SObject> objs) {
        List<NameSpecRequest> reqs = new List<NameSpecRequest>();
        for(SObject obj : objs) {
            if((obj.get(rule.filterField) == null)||(obj.get(rule.filterField) == rule.filterValue)) {
                NameSpecRequest req = new NameSpecRequest(rule,obj);
                reqs.add(req);
            }
        }
        return reqs;
    }
    
    private class NameRule {
        public Boolean active;
        public String obj;
        public String nameField;
        public String nameSpec;
        public String nameSpecProcessor;
        public Id id;
        public String DeveloperName;
        public String filterField;
        public String filterValue;
        public NameRule() {}
        public NameRule(Autonaming_Rule__mdt rule) {
            active = rule.Active__c; obj = rule.Object__c; nameField = rule.Naming_Result_Field__c;
            nameSpec = rule.Name_Spec__c; nameSpecProcessor = rule.NameSpec_Processor__c;
            id = rule.Id; developerName = rule.developerName; filterField = rule.Filter_Field__c;
            filterValue = rule.Filter_Value__c;
        }
    }
}