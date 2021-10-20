component extends="cbmailservices.models.AbstractProtocol" {

	/**
	* Initialize the Mailjet protocol
	*
	* @properties A map of configuration properties for the protocol
	*/
	public MailjetProtocol function init( struct properties = {} ) {
		super.init( argumentCollection = arguments );

		if ( ! structKeyExists( properties, "apiKey" ) ) {
			throw( "A Mailjet API key is required to use this protocol.  Please pass one in via the properties struct in your `config/ColdBox.cfc`." );
		}

		return this;
	}

	/**
	* Send a message via the Mailjet API
	*
	* @payload The payload to deliver
	*/
	public function send( required cbmailservices.models.Mail payload ) {
		var returnStruct = {error=true, errorArray=[], messageID=''};
		var mail      = payload.getMemento();

		var body = {
			"From": {
				"Email": mail.from
			}
		};

		if ( structKeyExists( mail, "fromName" ) && mail.fromName != "" ) {
			body[ "From" ][ "Name" ] = mail.fromName;
		}

		if ( structKeyExists( mail, "replyto" ) && mail.replyto != "" ) {
			body[ "ReplyTo" ][ "Email" ] = mail.replyto;
		}


		body[ "Subject" ] = mail.subject;

		body[ "To" ] = [];
		body[ "To" ].append( {"Email"=mail.to} );


		if ( mail.keyExists( "bcc" ) ) {
			mail.bcc = isArray( mail.bcc ) ? mail.bcc : mail.bcc.listToArray();
			if ( ! mail.bcc.isEmpty() ) {
				body[ "Bcc" ] = mail.bcc.map( function( address ) {
					return { "email" = address };
				} );
			}
		}

		if ( mail.keyExists( "cc" ) ) {
			mail.cc = isArray( mail.cc ) ? mail.cc : mail.cc.listToArray();
			if ( ! mail.cc.isEmpty() ) {
				body[ "Cc" ]  = mail.cc.map( function( address ) {
					return { "email" = address };
				} );
			}
		}

		if ( structKeyExists( mail, "additionalInfo" ) && isStruct( mail.additionalInfo ) ) {
			if ( structKeyExists( mail.additionalInfo, "categories" ) ) {
				if ( ! isArray( mail.additionalInfo.categories ) ) {
					mail.additionalInfo.categories = listToArray( mail.additionalInfo.categories );
				}
				body[ "categories" ] = mail.additionalInfo.categories;
			}

			if ( structKeyExists( mail.additionalInfo, "customArgs" ) ) {
				body[ "custom_args" ] = mail.additionalInfo.customArgs;
			}
		}

		var type = structKeyExists( mail, "type" ) ? mail.type : "plain";

		if ( type == "template" ) {
			body[ "TemplateID" ] = mail.body;
			//personalization[ "substitutions" ] = mail.bodyTokens;
		} else if (type == "HTML") {

			body[ "HTMLPart" ] = "#mail.body#";

		} else if (type == "plain") {

			body[ "TextPart" ] = "#mail.body#";

		}


		//body[ "personalizations" ] = [ personalization ];

		if ( structkeyExists( mail, 'mailparams' ) && isArray( mail.mailparams ) && ArrayLen( mail.mailparams ) ){
			body[ "Attachments" ] =  mail.mailParams
										.filter(function(mailParam){
											return StructKeyExists(mailParam, 'file');
										})
										.map( function(mailParam){

											return {
												'Base64Content': '#toBase64(fileReadBinary(mailParam.file))#',
												'Filename': listLast(mailParam.file, '/')
											};

										});
		}

		// Im Moment gibt es nur die Möglichkeit eine hohe Prio zu setzen
		if ( structkeyExists( mail, 'priority' ) && len(mail.priority) ){
			body[ 'headers' ] = {'Priority': 'Urgent', 'Importance': 'high', 'X-Priority': '1'};
		}
var messageData = {"Messages":[body]};
var messages = [];
writeDump(var=messageData,expand=true);
writeDump(var=serializeJson( messageData ),expand=true);
writeDump(var=body,expand=true);



		cfhttp( url = "https://api.mailjet.com/v3.1/send", method = "POST" ) {
			// cfhttpparam( type = "header", name = "Authorization", value="Bearer #getProperty( "apiKey" )#" );
			cfhttpparam( type = "header", name = "Authorization", value="Basic #ToBase64("#getProperty( "apiKey" )#:#getProperty( "apisecret" )#")#" );
			cfhttpparam( type = "header", name = "Content-Type", value="application/json" );
			cfhttpparam( type = "body", value = serializeJson( messageData ) );
		};
		writeDump(var=deserializeJSON( cfhttp.filecontent ),expand=true,label="httpResult");
		if ( left( cfhttp.status_code, 1 ) != "2" && left( cfhttp.status_code, 1 ) != "3"  ) {
			writeDump(var=deserializeJSON( cfhttp.filecontent ),expand=true);
			abort;

			returnStruct.errorArray = deserializeJSON( cfhttp.filecontent ).errors;
		}
		else {
			returnStruct.error = false;
		}
		if ( StructKeyExists(cfhttp,'responseheader') AND StructKeyExists(cfhttp.responseheader,'X-Message-Id') ) {
			returnStruct.messageID = cfhttp.responseheader['X-Message-Id'];
		}

		return returnStruct;
	}

}
