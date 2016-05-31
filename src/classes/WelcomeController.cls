/**
 * Controller logic ensures there is a valid connection to the Metadata API (aka a Remote Site Setting exists for the appropite URL)
 **/
public with sharing class WelcomeController {
	public String Host {get;set;}
	public String RemoteSiteName { get { return 'mdapi'; } }
	public String MetadataResponse {get;set;}
	public Boolean MetadataConnectionWarning {get;set;}
	public String MetadataApiException {get;set;}

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


	public PageReference checkMetadataAPIConnection() {
		// Get Host Domain
		Host = ApexPages.currentPage().getHeaders().get('Host');

		// Attempt to connect to the Metadata API
		MetadataConnectionWarning = false;
		if(!isMetadataAPIConnected()) {
			ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.Error, 'Unable to connect to the Salesforce Metadata API.'));
			ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.Error, 'A Remote Site Setting must be created in your org before you can use this tool.'));
			ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.Error, 'Press the Create Remote Site Setting button to perform this step or refer to the post install step below to perform this manually.'));
			MetadataConnectionWarning = true;
			MetadataApiException = '';
			if(LastMetadataAPIConnectionException!=null) {
				MetadataApiException = LastMetadataAPIConnectionException.getMessage();
			}
		}

		return null;
	}

	public PageReference displayMetadataResponse() {
		// Display the response from the client side Metadata API callout
		if(metadataResponse.length()==0) {
			ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.Info, 'Remote Site Setting ' + RemoteSiteName + ' has been created.' ));
			MetadataConnectionWarning = false;
		} else {
			ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.Error, metadataResponse));
			MetadataConnectionWarning = true;
		}
		return null;
	}
}