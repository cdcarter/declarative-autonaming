public with sharing class DAN_Manage_CTRL {
	public Autonaming_Rule__mdt autonamingRule {get;set;}
	// based on query param id or developername
	public String selectedRule {get;set;}
	public Boolean MetadataConnectionError {get;set;}
	public MetadataService.AsyncResult AsyncResult {get; private set;}
	public Boolean DeployedTrigger { get; set; }
	public Integer deployCount;
	public String NamingTriggerName { get; set; }
	public String NamingTriggerTestName { get; set; }
	public ApexTrigger NamingTrigger { get; private set; }
	public ApexClass NamingTriggerTest { get; private set; }
	public String ZipData { get; set; }
	private static final Integer APEXTRIGGER_NAME_LENGTH = 40;
	private static final Integer APEXCLASS_NAME_LENGTH = 40;

	public DAN_Manage_CTRL() {
		autonamingRule = (Autonaming_Rule__mdt)Autonaming_Rule__mdt.SObjectType.newSObject(null,true);
	}

	public PageReference init() {
		Host = ApexPages.currentPage().getHeaders().get('Host');

		MetadataConnectionError = !isMetadataAPIConnected();
		if(MetadataConnectionError) {
			return null;
		}

		selectedRule = (Id) ApexPages.currentPage().getParameters().get('id');
		if(selectedRule != null) {
			autonamingRule = (Autonaming_Rule__mdt) getRuleById(selectedRule);
		} else {
			selectedRule = ApexPages.currentPage().getParameters().get('developerName');
			if(selectedRule != null) {
				autonamingRule = (Autonaming_Rule__mdt) getRuleByDeveloperName(selectedRule);
				selectedRule = autonamingRule.Id;
			}
		}
		deployCount = 0;

		return null;
	}

	public void initDeploy() {
		init();

		NamingTriggerName = calculateComponentName(autonamingRule.Object__c, 'Trigger', APEXTRIGGER_NAME_LENGTH);
		NamingTriggerTestName = calculateComponentName(autonamingRule.Object__c, 'Test', APEXCLASS_NAME_LENGTH);

		// Already deployed?
		NamingTrigger = selectTriggerByName(NamingTriggerName);
		NamingTriggerTest = selectClassByName(NamingTriggerName);
		DeployedTrigger = (NamingTrigger != null);
		deployCount = 0;

		// Message to confirm current status
		if(DeployedTrigger) {
			ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.Info, 'Apex Trigger <b>' + NamingTriggerName + '</b> is installed.'));
			ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.Info, 'Apex Class <b>' + NamingTriggerTestName + '</b> is installed.'));
			ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.Info, 'Click <b>Remove</b> to uninstall the Apex Trigger and Apex Class for this object.'));
		} else {
			ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.Info, 'Click <b>Deploy</b> to install the Apex Trigger and Apex Class for this object.'));
		}
	}

	public List<SelectOption> getRules() {
		List<SelectOption> options = new List<SelectOption>{new SelectOption('[new]','Create new...')};
		for(Autonaming_Rule__mdt rule : getAllRules()) {
			options.add(new SelectOption(rule.Id,rule.Label));
		}
		return options;
	}

	public PageReference load() {
		// Reload the page
		PageReference newPage = Page.DAN_Manager;
		newPage.setRedirect(true);
		if(selectedRule != '[new]') {
			newPage.getParameters().put('id', selectedRule);
		}
		return newPage;
	}

	public PageReference save() {
		try {
			if(autonamingRule.Id==null)
			createRules(new List<SObject> { autonamingRule });
			else
			updateRules(new List<SObject> { autonamingRule });
			return load();
		} catch (Exception e) {
			ApexPages.addMessages(e);
		}
		return null;
	}

	public PageReference deleteX() {
		try {
			deleteRules(new List<String> { autonamingRule.DeveloperName });
			return load();
		} catch (Exception e) {
			ApexPages.addMessages(e);
		}
		return null;
	}

	public PageReference checkAsyncRequest() {
		// Check the status of the retrieve request
		MetadataService.MetadataPort service = createService();
		MetadataService.DeployResult deployResult = service.checkDeployStatus(AsyncResult.Id, true);
		if(deployResult.done) {
			ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.Info, DeployedTrigger ? 'Remove complete.' : 'Deployment complete.'));

			// Deployment errors?
			if(deployResult.details!=null && deployResult.details.componentFailures!=null)
			for(MetadataService.DeployMessage deployMessage : deployResult.details.componentFailures)
			if(deployMessage.problem!=null)
			ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.Error, deployMessage.fileName + ' (Line: ' + deployMessage.lineNumber + ': Column:' + deployMessage.columnNumber + ') : ' + deployMessage.problem));

			// Test errors?
			MetadataService.RunTestsResult runTestResult = deployResult.details.runTestResult;

			if(runTestResult.numFailures > 0)
			for(MetadataService.RunTestFailure testFailure : runTestResult.failures)
			ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.Error, testFailure.name + '.' + testFailure.methodName + ' ' + testFailure.message + ' ' + testFailure.stackTrace));

			// Code coverage warnings?
			if(runTestResult.codeCoverageWarnings!=null)
			for(MetadataService.CodeCoverageWarning codeCoverageWarning : runTestResult.codeCoverageWarnings)
			ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.Warning, (codeCoverageWarning.namespace!=null ? codeCoverageWarning.namespace+'.' : '') + codeCoverageWarning.name + ':' + codeCoverageWarning.message));

			// reset the state of the world
			AsyncResult = null;
			if(deployResult.success) {
				DeployedTrigger = !DeployedTrigger;
			}
		} else {
			ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.Info, (DeployedTrigger ? 'Removing...' : 'Deploying...') + '.'.repeat(deployCount++)));
		}
		return null;
	}

	public String getPackageXml() {
		if(DeployedTrigger) {
			// package.xml for undeploy
			return
			'<?xml version="1.0" encoding="UTF-8"?>' +
			'<Package xmlns="http://soap.sforce.com/2006/04/metadata">' +
			'<version>28.0</version>' +
			'</Package>';
		} else {
			return
			'<?xml version="1.0" encoding="UTF-8"?>' +
			'<Package xmlns="http://soap.sforce.com/2006/04/metadata">' +
			'<types>' +
			'<members>'+NamingTriggerName+'</members>' +
			'<name>ApexTrigger</name>' +
			'</types>' +
			'<types>' +
			'<members>'+NamingTriggerTestName+'</members>' +
			'<name>ApexClass</name>' +
			'</types>' +
			'<version>28.0</version>' +
			'</Package>';

		}
	}

	public String getDestructiveChangesXml() {
		return
		'<?xml version="1.0" encoding="UTF-8"?>' +
		'<Package xmlns="http://soap.sforce.com/2006/04/metadata">' +
		'<types>' +
		'<members>'+NamingTriggerName+'</members>' +
		'<name>ApexTrigger</name>' +
		'</types>' +
		'<types>' +
		'<members>'+NamingTriggerTestName+'</members>' +
		'<name>ApexClass</name>' +
		'</types>' +
		'<version>28.0</version>' +
		'</Package>';
	}

	public String getTriggerTestCodeMetadata() {
		return
		'<?xml version="1.0" encoding="UTF-8"?>' +
		'<ApexClass xmlns="http://soap.sforce.com/2006/04/metadata">' +
		'<apiVersion>28.0</apiVersion>' +
		'<status>Active</status>' +
		'</ApexClass>';
	}

	public String getTriggerTestCode()	{
		if(DeployedTrigger && NamingTriggerTest!=null){
			// Display currently deployed code for confirmation
			return NamingTriggerTest.Body;
		} else {
			// Deploy generated code
			return
			'/**\n' +
			' * Auto Generated and Deployed by the Declarative Autonaming package (dan)\n' +
			' **/\n' +
			'@IsTest\n' +
			'private class ' + NamingTriggerTestName +  '{\n' +
			'    @IsTest private static void testTrigger() {\n' +
			'        // Force the ' + NamingTriggerName + ' to be invoked, fails the test if org config or other Apex code prevents this.\n' +
			'        ' + (namespace().length() > 0 ? namespace() + '.' : '') + 'DAN.testHandler(new ' + autonamingRule.Object__c + '(Name =\'test\'));\n' +
			'    }\n' +
			'}';
		}
	}

	public String getTriggerCodeMetadata() {
		return
		'<?xml version="1.0" encoding="UTF-8"?>' +
		'<ApexTrigger xmlns="http://soap.sforce.com/2006/04/metadata">' +
		'<apiVersion>28.0</apiVersion>' +
		'<status>Active</status>' +
		'</ApexTrigger>';
	}

	public String getTriggerCode(){
		if(DeployedTrigger && NamingTrigger!=null) {
			// Display currently deployed code for confirmation
			return NamingTrigger.Body;
		} else {
			// Deploy generated code
			return
			'/**\n' +
			' * Auto Generated and Deployed by the Declarative Autonaming package (dan)\n' +
			' **/\n' +
			'trigger ' + NamingTriggerName + ' on ' + autonamingRule.Object__c + ' (after insert, after undelete, after update) {\n'+
			'    '+ (namespace().length() > 0 ? namespace() + '.' : '') + 'DAN.handleAfterTrigger(Trigger.new);\n'+
			'}\n';
		}
	}

	public PageReference deployZip() {
		ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.Info, DeployedTrigger ? 'Removing...' : 'Deploying...'));

		// Deploy zip file posted back from the page action function
		MetadataService.MetadataPort service = createService();
		MetadataService.DeployOptions deployOptions = new MetadataService.DeployOptions();
		deployOptions.testLevel = 'RunSpecifiedTests';
		deployOptions.runTests = new List<String> { NamingTriggerTestName };
		deployOptions.allowMissingFiles = false;
		deployOptions.autoUpdatePackage = false;
		deployOptions.checkOnly = false;
		deployOptions.ignoreWarnings = false;
		deployOptions.performRetrieve = false;
		deployOptions.purgeOnDelete = false;
		deployOptions.rollbackOnError = true;
		deployOptions.singlePackage = true;
		AsyncResult = service.deploy(ZipData, DeployOptions);
		return null;
	}

	private static String calculateComponentName(String objName, String suffix, Integer maxComponentNameLength) {
		String trimmedObjectName = objName.replace('__c', '').replace('__', '_');
		String prefix = '';// Utilities.componentPrefix();
		String componentName = prefix + trimmedObjectName + suffix;
		Integer componentNameLength = componentName.length();
		if(componentNameLength > maxComponentNameLength) {
			Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
			SObjectType objType = gd.get(objName);
			String objPrefix = objType.getDescribe().getKeyPrefix(); // Key prefix will be used to make the trimmed name unique again
			Integer overflowChars = componentNameLength - maxComponentNameLength; // How much do we need to trim the name by?
			trimmedObjectName = trimmedObjectName.substring(0, trimmedObjectName.length() - overflowChars); // Trim the overflow characters from the name
			trimmedObjectName = trimmedObjectName.substring(0, trimmedObjectName.length() - objPrefix.length()); // Trim space for the prefix on the end
			trimmedObjectName+= objPrefix; // Add on the end the unique object prefix (to ensure the trimmed name is still unique)
			componentName = prefix + trimmedObjectName + suffix;
		}
		return componentName;
	}

	private static ApexClass selectClassByName(String name) {
		List<ApexClass> ret = [SELECT Id,Name,Body FROM ApexClass WHERE Name = :name LIMIT 1];
		if(ret.size() > 0) return ret[0]; else return null;
	}

	private static ApexTrigger selectTriggerByName(String name){
		List<ApexTrigger> ret = [SELECT Id,Name,Body FROM ApexTrigger WHERE Name = :name LIMIT 1];
		if(ret.size() > 0) return ret[0]; else return null;
	}

	private static String namespace() {
		Schema.DescribeSObjectResult describe = Autonaming_Rule__mdt.sObjectType.getDescribe();
		String name = describe.getName();
		String localName = describe.getLocalName();
		String namespace = name.removeEnd(localName).removeEnd('__');
		return namespace;
	}

	private static MetadataService.MetadataPort createService() {
		MetadataService.MetadataPort service = new MetadataService.MetadataPort();
		service.SessionHeader = new MetadataService.SessionHeader_element();
		service.SessionHeader.sessionId = UserInfo.getSessionId();
		return service;
	}

	private static List<Id> createRules(List<SObject> ruleRecords) {
		CustomMetadataService.createMetadata(ruleRecords);
		return null;
	}

	private static List<Id> updateRules(List<SObject> ruleRecords) {
		CustomMetadataService.updateMetadata(ruleRecords);
		return null;
	}

	private static void deleteRules(List<String> ruleNames) {
		// Currently assumes the Id's are Custom Metadata record DeveloperName's
		CustomMetadataService.deleteMetadata(Autonaming_Rule__mdt.getSObjectType(), ruleNames);
	}

	public static Autonaming_Rule__mdt getRuleById(Id i) {
		return [SELECT Id, DeveloperName,Label,Active__c, Name_Spec__c, NameSpec_Processor__c, Naming_Result_Field__c, Object__c FROM Autonaming_Rule__mdt WHERE Id = :i LIMIT 1];
	}

	public static Autonaming_Rule__mdt getRuleByDeveloperName(String devName) {
		return [SELECT Id, DeveloperName,Label,Active__c, Name_Spec__c, NameSpec_Processor__c, Naming_Result_Field__c, Object__c FROM Autonaming_Rule__mdt WHERE DeveloperName = :devName LIMIT 1];
	}

	public static List<Autonaming_Rule__mdt> getAllRules() {
		return [SELECT Id, DeveloperName,Label,Active__c, Name_Spec__c, NameSpec_Processor__c, Naming_Result_Field__c, Object__c FROM Autonaming_Rule__mdt];
	}

	public static Exception LastMetadataAPIConnectionException {get; private set;}

	public static Boolean isMetadataAPIConnected() {
		try {
			MetadataService.MetadataPort service = new MetadataService.MetadataPort();
			service.SessionHeader = new MetadataService.SessionHeader_element();
			service.SessionHeader.sessionId = UserInfo.getSessionId();
			List<MetadataService.ListMetadataQuery> queries = new List<MetadataService.ListMetadataQuery>();
			MetadataService.ListMetadataQuery remoteSites = new MetadataService.ListMetadataQuery();
			remoteSites.type_x = 'RemoteSiteSetting';
			queries.add(remoteSites);
			service.listMetadata(queries, 28);
		} catch (Exception e) {
			LastMetadataAPIConnectionException = e;
			return false;
		}
		LastMetadataAPIConnectionException = null;
		return true;
	}


	public String Host {get;set;}
	public String RemoteSiteName { get { return namespace() + 'mdapi'; } }
	public String MetadataResponse {get;set;}
	public String MetadataApiException {get;set;}

	public PageReference displayMetadataResponse() {
		// Display the response from the client side Metadata API callout
		if(metadataResponse.length()==0) {
			ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.Info, 'Remote Site Setting ' + RemoteSiteName + ' has been created.' ));
			MetadataConnectionError = false;
		} else {
			ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.Error, metadataResponse));
			MetadataConnectionError = true;
		}
		return null;
	}
}