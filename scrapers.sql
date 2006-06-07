-- 4
DELETE FROM scrapers;
INSERT INTO "scrapers" VALUES(1, NULL, NULL, 20060603002000, 'Amazon.com Scraper', 'Simon Kornblith', '^http://www\.amazon\.com/gp/product/', NULL, 'var prefixRDF = ''http://www.w3.org/1999/02/22-rdf-syntax-ns#'';
var prefixDC = ''http://purl.org/dc/elements/1.1/'';
var prefixDCMI = ''http://purl.org/dc/dcmitype/'';
var prefixDummy = ''http://chnm.gmu.edu/firefox-scholar/'';

var namespace = doc.documentElement.namespaceURI;
var nsResolver = namespace ? function(prefix) {
	if (prefix == ''x'') return namespace; else return null;
} : null;

var getNode = function(doc, contextNode, xpath, nsResolver) {
	return doc.evaluate(xpath, contextNode, nsResolver, XPathResult.ANY_TYPE,null).iterateNext();
}

var cleanString = function(s) {
	s = utilities.trimString(s);
	return s.replace(/ +/g, " ");
}

var uri = doc.location.href;

model.addStatement(uri, prefixRDF + "type", prefixDummy + "book", false);

// Retrieve authors
var xpath = ''/html/body/table/tbody/tr/td[2]/form/div[@class="buying"]/a'';
var elmts = utilities.gatherElementsOnXPath(doc, doc, xpath, nsResolver);
for (var i = 0; i < elmts.length; i++) {
	var elmt = elmts[i];
	
	model.addStatement(uri, prefixDC + ''creator'', cleanString(getNode(doc, elmt, ''./text()[1]'', nsResolver).nodeValue), false); // Use your own type here
}

// Retrieve data from "Product Details" box
var xpath = ''/html/body/table/tbody/tr/td[2]/table/tbody/tr/td[@class="bucket"]/div[@class="content"]/ul/li'';
var elmts = utilities.gatherElementsOnXPath(doc, doc, xpath, nsResolver);
for (var i = 0; i < elmts.length; i++) {
	var elmt = elmts[i];
	var attribute = cleanString(getNode(doc, elmt, ''./B[1]/text()[1]'', nsResolver).nodeValue);
	if(getNode(doc, elmt, ''./text()[1]'', nsResolver)) {
		var value = cleanString(getNode(doc, elmt, ''./text()[1]'', nsResolver).nodeValue);
		
		if(attribute == "Publisher:") {
			if(value.lastIndexOf("(") != -1) {
				var date = value.substring(value.lastIndexOf("(")+1, value.length-1);
				value = value.substring(0, value.lastIndexOf("(")-1);
			}
			if(value.lastIndexOf(";") != -1) {
				var edition = value.substring(value.lastIndexOf(";")+2, value.length);
				value = value.substring(0, value.lastIndexOf(";"));
			}
			model.addStatement(uri, prefixDC + ''publisher'', value);
			model.addStatement(uri, prefixDC + ''date'', date);
			model.addStatement(uri, prefixDC + ''hasVersion'', edition);
		} else if(attribute == "Language:") {
			model.addStatement(uri, prefixDC + ''language'', value);
		} else if(attribute == "ISBN:") {
			model.addStatement(uri, prefixDC + ''identifier'', ''ISBN ''+value);
		} else if(value.substring(value.indexOf(" ")+1, value.length) == "pages") {
			model.addStatement(uri, prefixDummy + ''pages'', value.substring(0, value.indexOf(" ")));
			model.addStatement(uri, prefixDC + ''medium'', attribute.substring(0, attribute.indexOf(":")));
		}
	}
}

var xpath = ''/html/body/table/tbody/tr/td[2]/form/div[@class="buying"]/b[@class="sans"]'';
var elmts = utilities.gatherElementsOnXPath(doc, doc, xpath, nsResolver);
var title = cleanString(getNode(doc, elmts[0], ''./text()[1]'', nsResolver).nodeValue);
if(title.lastIndexOf("(") != -1 && title.lastIndexOf(")") == title.length-1) {
	title = title.substring(0, title.lastIndexOf("(")-1);
}
model.addStatement(uri, prefixDC + ''title'', title);');

INSERT INTO "scrapers" VALUES(2, NULL, NULL, 20060603002000, 'WorldCat Scraper', 'Simon Kornblith', '^http://newfirstsearch\.oclc\.org/WebZ/',
'if(doc.title == ''FirstSearch: WorldCat Detailed Record'') {
	return true;
}
return false;',
'var prefixRDF = ''http://www.w3.org/1999/02/22-rdf-syntax-ns#'';
var prefixDC = ''http://purl.org/dc/elements/1.1/'';
var prefixDCMI = ''http://purl.org/dc/dcmitype/'';
var prefixDummy = ''http://chnm.gmu.edu/firefox-scholar/'';

var sessionRegexp = /(?:\?|\:)sessionid=([^?:]+)(?:\?|\:|$)/;
var numberRegexp = /(?:\?|\:)recno=([^?:]+)(?:\?|\:|$)/;
var resultsetRegexp = /(?:\?|\:)resultset=([^?:]+)(?:\?|\:|$)/;
var lineRegexp = /^([\w() ]+): *(.*)$/;
var publisherRegexp = /^(.*), (.*?),?$/;

var uri = doc.location.href;

var sMatch = sessionRegexp.exec(uri);
var sessionid = sMatch[1];

var nMatch = numberRegexp.exec(uri);
if(nMatch) {
	var number = nMatch[1];
} else {
	number = 1;
}

var rMatch = resultsetRegexp.exec(uri);
if(rMatch) {
	var resultset = rMatch[1];
} else {
	// It''s in an XPCNativeWrapper, so we have to do this black magic
	resultset = doc.forms.namedItem(''main'').elements.namedItem(''resultset'').value;
}

var newUri = ''http://newfirstsearch.oclc.org/WebZ/DirectExport?numrecs=10:smartpage=directexport:entityexportnumrecs=10:entityexportresultset='' + resultset + '':entityexportrecno='' + number + '':sessionid='' + sessionid + '':entitypagenum=35:0'';

model.addStatement(uri, prefixRDF + "type", prefixDummy + "book", false);

function cleanAuthor(author) {
	author = author.replace(/^[\s\.\,\/\[\]\:]+/, '''');
	author = author.replace(/[\s\,\/\[\]\:\.]+$/, '''');
	// Add period for initials
	if(author.substring(author.length-2, author.length-1) == " ") {
		author += ".";
	}
	var splitNames = author.split('', '');
	if(splitNames.length > 1) {
		author = splitNames[1]+'' ''+splitNames[0];
	}
	return author;
}

utilities.HTTPUtilities.doPost(newUri, ''exportselect=record&exporttype=plaintext'', null, function(text) {
	var lines = text.split(''\n'');
	for(var i=0;i<lines.length;i++) {
		match = lineRegexp.exec(lines[i]);
		if(match) {
			if(match[1] == ''Title'') {
				var title = match[2];
				if(!lineRegexp.test(lines[i+1])) {
					i++;
					title += '' ''+lines[i];
				}
				if(title.substring(title.length-2) == " /") {
					title = title.substring(0, title.length-2);
				}
				model.addStatement(uri, prefixDC + ''title'', title);
			} else if(match[1] == ''Author(s)'') {
				var authors = match[2].split('';'');
				if(authors) {
					model.addStatement(uri, prefixDC + ''creator'', cleanAuthor(authors[0]));
					for(var j=1; j<authors.length; j+=2) {
						if(authors[j-1].substring(0, 1) == ''('') {
							j++;
						}
						model.addStatement(uri, prefixDC + ''creator'', cleanAuthor(authors[j]));
					}
				} else {
						model.addStatement(uri, prefixDC + ''creator'', utilities.trimString(match[2]));
				}
			} else if(match[1] == ''Publication'') {
				// Don''t even try to deal with this. The WorldCat metadata is of poor enough quality that this isn''t worth it.
				match[2] = utilities.trimString(match[2]);
				if(match[2].substring(match[2].length-1) == '','') {
						match[2] = match[2].substring(0, match[2].length-1);
				}
				model.addStatement(uri, prefixDC + ''publisher'', match[2]);
			} else if(match[1] == ''Language'') {
				model.addStatement(uri, prefixDC + ''language'', utilities.trimString(match[2]));
			} else if(match[1] == ''Standard No'') {
				var identifiers = match[2].split(/ +/);
				var j=0;
				while(j<(identifiers.length-1)) {
						var type = identifiers[j].substring(0, identifiers[j].length-1);
						var lastChar;
						var value;

						j++;
						while(j<identifiers.length && (lastChar = identifiers[j].substring(identifiers[j].length-1)) != '':'') {
							if(identifiers[j].substring(0, 1) != ''('') {
								if(lastChar == '';'') {
									value = identifiers[j].substring(0, identifiers[j].length-1);
								} else {
									value = identifiers[j];
								}
								model.addStatement(uri, prefixDC + ''identifier'', type + '' '' + value);
							}
							j++;
						}
				}
			} else if(match[1] == ''Year'') {
				model.addStatement(uri, prefixDC + ''year'', match[2]);
			}
		}
	}
	
	done();
})
wait();');

INSERT INTO "scrapers" VALUES(3, NULL, NULL, 20060603002000, 'LOC/Voyager WebVoyage Scraper', 'Simon Kornblith', 'Pwebrecon\.cgi',
'try {
	if(doc.forms.namedItem(''frm'').elements.namedItem(''RC'')) {
		return false;
	}
	var export_options = doc.forms.namedItem(''frm'').elements.namedItem(''RD'').options;
	for(i in export_options) {
		if(export_options[i].text == ''Latin1 MARC''
		|| export_options[i].text == ''Raw MARC''
		|| export_options[i].text == ''UTF-8''
		|| export_options[i].text == ''MARC (Unicode/UTF-8)''
		|| export_options[i].text == ''MARC (non-Unicode/MARC-8)'') {
			return true;
		}
	}
	return false;
} catch(e) {
	return false;
}',
'var prefixRDF = ''http://www.w3.org/1999/02/22-rdf-syntax-ns#'';
var prefixDC = ''http://purl.org/dc/elements/1.1/'';
var prefixDCMI = ''http://purl.org/dc/dcmitype/'';
var prefixDummy = ''http://chnm.gmu.edu/firefox-scholar/'';

var uri = doc.location.href;

var raw, unicode, latin1;

var form = doc.forms.namedItem(''frm'');
var newUri = form.action;
var postString = '''';
for(i in form.elements) {
	if(form.elements[i].type == ''HIDDEN'' || form.elements[i].type == ''hidden'') {
		postString += escape(form.elements[i].name)+''=''+escape(form.elements[i].value)+''&'';
	}
}

var export_options = form.elements.namedItem(''RD'').options;
for(i in export_options) {
	if(export_options[i].text == ''Raw MARC''
	|| export_options[i].text == ''MARC (non-Unicode/MARC-8)'') {
		raw = i;
	}  if(export_options[i].text == ''Latin1 MARC'') {
		latin1 = i;
	} else if(export_options[i].text == ''UTF-8''
	|| export_options[i].text == ''MARC (Unicode/UTF-8)'') {
		unicode = i;
	}
}
postString += ''RD=''+i+''&MAILADDY=&SAVE=Press+to+SAVE+or+PRINT'';

model.addStatement(uri, prefixRDF + ''type'', prefixDummy + ''book'', false);

// No idea why this doesn''t work as post
utilities.HTTPUtilities.doGet(newUri+''?''+postString, null, function(text) {
	var record = new MARC_Record();
	record.load(text, "binary");
	model = utilities.importMARCRecord(record, uri, model);
	done();
})
wait();');

INSERT INTO "scrapers" VALUES(4, NULL, NULL, 20060603002000, 'JSTOR Scraper', 'Simon Kornblith', '^http://www\.jstor\.org/(?:view|browse)', NULL, 'var prefixRDF = ''http://www.w3.org/1999/02/22-rdf-syntax-ns#'';
var prefixDC = ''http://purl.org/dc/elements/1.1/'';
var prefixDCMI = ''http://purl.org/dc/dcmitype/'';
var prefixDummy = ''http://chnm.gmu.edu/firefox-scholar/'';

var namespace = doc.documentElement.namespaceURI;
var nsResolver = namespace ? function(prefix) {
	if (prefix == ''x'') return namespace; else return null;
} : null;

var getNode = function(doc, contextNode, xpath, nsResolver) {
	return doc.evaluate(xpath, contextNode, nsResolver, XPathResult.ANY_TYPE,null).iterateNext();
}

var cleanString = function(s) {
	s = utilities.trimString(s);
	return s.replace(/ +/g, " ");
}

var uri = doc.location.href;


// If this is a view page, find the link to the citation
var xpath = ''/html/body/div[@class="indent"]/center/font/p/a[@class="nav"]'';
var elmts = utilities.gatherElementsOnXPath(doc, doc, xpath, nsResolver);
if(!elmts) {
	var xpath = ''/html/body/div[@class="indent"]/center/p/font/a[@class="nav"]'';
	var elmts = utilities.gatherElementsOnXPath(doc, doc, xpath, nsResolver);
}
if(!elmts) {
	exit;
}
var saveCitation = getNode(doc, elmts[0], ''.'', nsResolver).href;
var viewSavedCitations = getNode(doc, elmts[1], ''.'', nsResolver).href;
saveCitation = saveCitation.replace(''citationAction=remove'', ''citationAction=save'');

// Parse save citation link
var importantCitationRegexp = /userID.*$/;
var match = importantCitationRegexp.exec(viewSavedCitations);
var postData = match[0]+''&citationAction=removeAll&confirmRemAll=on'';
utilities.HTTPUtilities.doPost(''http://www.jstor.org/browse'', postData, null, function() {	// clear marked
	utilities.HTTPUtilities.doGet(saveCitation, null, function() {								// mark this
		utilities.HTTPUtilities.doGet(''http://www.jstor.org/browse/citations.txt?exportAction=Save+as+Text+File&exportFormat=cm&''+match[0], null, function(text) {
																								// get marked
			var lines = text.split("\n");
			var haveStarted = false;
			
			var data = new Object();
			data[prefixDC + "title"] = new Array();
			data[prefixDC + "creator"] = new Array();
			data[prefixDummy + "publication"] = new Array();
			data[prefixDummy + "volume"] = new Array();
			data[prefixDummy + "number"] = new Array();
			data[prefixDummy + "series"] = new Array();
			data[prefixDC + "date"] = new Array();
			data[prefixDummy + "pages"] = new Array();
			data[prefixDC + "identifier"] = new Array();
			data[prefixDC + "publisher"] = new Array();
			
			var stableURL;
			
			for(i in lines) {
				if(haveStarted) {
					var fieldCode = lines[i].substring(0, 2);
					var fieldContent = cleanString(lines[i].substring(5));
					
					if(lines[i].substring(2, 5) != " : ") {
						break;
					}
					
					if(fieldCode == "TI") {
						data[prefixDC + "title"].push(fieldContent);
					} else if(fieldCode == "AU") {
						var authors = fieldContent.split(";");
						for(j in authors) {
							var author = authors[j];
							if(author) {
								var splitNames = author.split('', '');
								if(splitNames) {
									author = splitNames[1]+'' ''+splitNames[0];
								}
								data[prefixDC + "creator"].push(author);
							}
						}
					} else if(fieldCode == "SO") {
						data[prefixDummy + "publication"].push(fieldContent);
					} else if(fieldCode == "VO") {
						data[prefixDummy + "volume"].push(fieldContent);
					} else if(fieldCode == "NO") {
						data[prefixDummy + "number"].push(fieldContent);
					} else if(fieldCode == "SE") {
						data[prefixDummy + "series"].push(fieldContent);
					} else if(fieldCode == "DA") {
						data[prefixDC + "date"].push(fieldContent);
					} else if(fieldCode == "PP") {
						data[prefixDummy + "pages"].push(fieldContent);
					} else if(fieldCode == "EI") {
						stableURL = fieldContent;
					} else if(fieldCode == "IN") {
						data[prefixDC + "identifier"].push("ISSN "+fieldContent);
					} else if(fieldCode == "PB") {
						data[prefixDC + "publisher"].push(fieldContent);
					}
				}
				if(lines[i].substring(0,3) == "<1>") {
					haveStarted = true;
				}
			}
			
			// Loop through again so that we can add with the stableURL
			model.addStatement(stableURL, prefixRDF + "type", prefixDummy + "journal", false);
			for(i in data) {
				if(data[i].length) {
					for(j in data[i]) {
						model.addStatement(stableURL, i, data[i][j]);
					}
				}
			}
			
			done();
		})
	})
});

wait();');

INSERT INTO "scrapers" VALUES(5, NULL, NULL, 20060603002000, 'History Cooperative Scraper', 'Simon Kornblith', '^http://www\.historycooperative\.org/journals/.+/.+/.+\.html', NULL, 'var prefixRDF = ''http://www.w3.org/1999/02/22-rdf-syntax-ns#'';
var prefixDC = ''http://purl.org/dc/elements/1.1/'';
var prefixDCMI = ''http://purl.org/dc/dcmitype/'';
var prefixDummy = ''http://chnm.gmu.edu/firefox-scholar/'';

var uri = doc.location.href;

model.addStatement(uri, prefixRDF + "type", prefixDummy + "journal", false);

var month, year;

var metaTags = doc.getElementsByTagName("meta");

function associateMeta(field, rdfUri) {
	var field = metaTags.namedItem(field);
	if(field) {
		model.addStatement(uri, rdfUri, field.getAttribute("content"), false);
	}
}

associateMeta("Title", prefixDC + "title");
associateMeta("Journal", prefixDummy + "publication");
associateMeta("Volume", prefixDummy + "volume");
associateMeta("Issue", prefixDummy + "number");

var author = metaTags.namedItem("Author");
if(author) {
	var authors = author.getAttribute("content").split(" and ");
	for(j in authors) {
		model.addStatement(uri, prefixDC + "creator", authors[j], false);
	}
}

var month = metaTags.namedItem("PublicationMonth");
var year = metaTags.namedItem("PublicationYear");
if(month && year) {
	model.addStatement(uri, prefixDC + "date", month.getAttribute("content")+" "+year.getAttribute("content"), false);
}
');

INSERT INTO "scrapers" VALUES(6, NULL, NULL, 20060603002000, 'InnoPAC Scraper', 'Simon Kornblith', '^http://[^/]+/search/[^/]+/[^/]+/1\%2C[^/]+/frameset\&FF=', NULL,
'var prefixRDF = ''http://www.w3.org/1999/02/22-rdf-syntax-ns#'';
var prefixDC = ''http://purl.org/dc/elements/1.1/'';
var prefixDCMI = ''http://purl.org/dc/dcmitype/'';
var prefixDummy = ''http://chnm.gmu.edu/firefox-scholar/'';

var uri = doc.location.href;

var matchRegexp = new RegExp(''^(http://[^/]+/search/[^/]+/[^/]+/1\%2C[^/]+/)frameset(.+)$'');
var m = matchRegexp.exec(uri);
var newUri = m[1]+''marc''+m[2];

utilities.loadDocument(newUri, browser, function(newBrowser) {
	newDoc = newBrowser.contentDocument;
	
	var namespace = newDoc.documentElement.namespaceURI;
	var nsResolver = namespace ? function(prefix) {
	  if (prefix == ''x'') return namespace; else return null;
	} : null;
		
	var getNode = function(doc, contextNode, xpath, nsResolver) {
	  return doc.evaluate(xpath, contextNode, nsResolver, XPathResult.ANY_TYPE,null).iterateNext();
	}
	
	var xpath = ''//pre'';
	var elmts = utilities.gatherElementsOnXPath(newDoc, newDoc, xpath, nsResolver);
	
	var text = getNode(doc, elmts[0], ''./text()[1]'', nsResolver).nodeValue;
	
	var record = new MARC_Record();
	record.load(text, "MARC_PAC");
	model = utilities.importMARCRecord(record, uri, model);
	done();
}, function() {});

wait();');

INSERT INTO "scrapers" VALUES(7, NULL, NULL, 20060603002000, 'SIRSI 2003+ Scraper', 'Simon Kornblith', '/uhtbin/cgisirsi',
'var namespace = doc.documentElement.namespaceURI;
var nsResolver = namespace ? function(prefix) {
	if (prefix == ''x'') return namespace; else return null;
} : null;

var xpath = ''//tr[th[@class="viewmarctags"]][td[@class="viewmarctags"]]'';
var elmts = utilities.gatherElementsOnXPath(doc, doc, xpath, nsResolver);
if(elmts.length) {
	return true;
}
return false;',
'var prefixRDF = ''http://www.w3.org/1999/02/22-rdf-syntax-ns#'';
var prefixDC = ''http://purl.org/dc/elements/1.1/'';
var prefixDCMI = ''http://purl.org/dc/dcmitype/'';
var prefixDummy = ''http://chnm.gmu.edu/firefox-scholar/'';

var namespace = doc.documentElement.namespaceURI;
var nsResolver = namespace ? function(prefix) {
	if (prefix == ''x'') return namespace; else return null;
} : null;

var getNode = function(doc, contextNode, xpath, nsResolver) {
  return doc.evaluate(xpath, contextNode, nsResolver, XPathResult.ANY_TYPE,null).iterateNext();
}

function stringTrimmer(x) {
	var x = x.replace(/^[^\w(]+/, "");
	return x.replace(/[^\w)]+$/, "");
}

function getAnyNumber(x) {
	var re = /[0-9]+/;
	var m = re.exec(x);
	if(m) {
		return m[0];
	}
}

function getISBN(x) {
	var re = /^[0-9](?:[0-9X]+)/;
	var m = re.exec(x);
	if(m) {
		return m[0];
	}
}

function cleanAuthor(author) {
	author = author.replace(/^[\s\.\,\/\[\]\:]+/, '''');
	author = author.replace(/[\s\,\/\[\]\:\.]+$/, '''');
	// Add period for initials
	if(author.substring(author.length-2, author.length-1) == " ") {
		author += ".";
	}
	var splitNames = author.split('', '');
	if(splitNames.length > 1) {
		author = splitNames[1]+'' ''+splitNames[0];
	}
	return author;
}

var uri = doc.location.href;
var data = new Object();

var xpath = ''//tr[th[@class="viewmarctags"]][td[@class="viewmarctags"]]'';
var elmts = utilities.gatherElementsOnXPath(doc, doc, xpath, nsResolver);
for (var i = 0; i < elmts.length; i++) {
	var elmt = elmts[i];
	try {
		var node = getNode(doc, elmt, ''./TD[1]/A[1]/text()[1]'', nsResolver);
		if(!node) {
			var node = getNode(doc, elmt, ''./TD[1]/text()[1]'', nsResolver);
		}
		if(node) {
			var field = stringTrimmer(getNode(doc, elmt, ''./TH[1]/text()[1]'', nsResolver).nodeValue);
			field = field.toLowerCase();
			var value = stringTrimmer(node.nodeValue);
			var rdfUri = null;
			if(field == "publisher") {
				rdfUri = prefixDC + ''publisher'';
			} else if(field == "pub date") {
				rdfUri = prefixDC + ''date'';
				value = getAnyNumber(value);
			} else if(field == "isbn") {
				rdfUri = prefixDC + ''identifier'';
				value = ''ISBN ''+getISBN(value);
			} else if(field == "title") {
				rdfUri = prefixDC + ''title'';
				var titleParts = value.split(" / ");
				value = titleParts[0];
			} else if(field == "publication info") {
				rdfUri = prefixDummy + ''place'';
				var pubParts = value.split(" : ");
				value = pubParts[0];
			} else if(field == "personal author") {
				rdfUri = prefixDC + ''creator'';
				value = cleanAuthor(node.nodeValue);
			} else if(field == "added author") {
				rdfUri = prefixDC + ''contributor'';
				value = cleanAuthor(node.nodeValue);
			} else if(field == "corporate author") {
				rdfUri = prefixDC + ''creator'';
			}
			if(rdfUri) {
				var insert = true;
				if(data && data[rdfUri]) {
					for(j in data[rdfUri]) {
						if(data[rdfUri][j] == value) {
							insert = false;
							break;
						}
					}
				} else if(!data[rdfUri]) {
					data[rdfUri] = new Array();
				}
				if(insert) {
					data[rdfUri].push(value);
					model.addStatement(uri, rdfUri, value, true);
				}
			}
		}
	} catch (e) {}
	
} 
');

INSERT INTO "scrapers" VALUES(8, NULL, NULL, 20060603002000, 'ProQuest Scraper', 'Simon Kornblith', 'http://proquest\.umi\.com/pqdweb\?(?:.*\&)?did=', '',
'var prefixRDF = ''http://www.w3.org/1999/02/22-rdf-syntax-ns#'';
var prefixDC = ''http://purl.org/dc/elements/1.1/'';
var prefixDCMI = ''http://purl.org/dc/dcmitype/'';
var prefixDummy = ''http://chnm.gmu.edu/firefox-scholar/'';

var namespace = doc.documentElement.namespaceURI;
var nsResolver = namespace ? function(prefix) {
	if (prefix == ''x'') return namespace; else return null;
} : null;

var getNode = function(doc, contextNode, xpath, nsResolver) {
  return doc.evaluate(xpath, contextNode, nsResolver, XPathResult.ANY_TYPE,null).iterateNext();
}

function stringTrimmer(x) {
	var x = x.replace(/^[^\w(]+/, "");
	return x.replace(/[^\w)]+$/, "");
}

function getPageRange(x) {
	var re = /[0-9\-]+/;
	var m = re.exec(x);
	if(m) {
		return m[0];
	}
}

function cleanAuthor(author) {
	author = author.replace(/^[\s\.\,\/\[\]\:]+/, '''');
	author = author.replace(/[\s\,\/\[\]\:\.]+$/, '''');
	// Add period for initials
	if(author.substring(author.length-2, author.length-1) == " ") {
		author += ".";
	}
	var splitNames = author.split('', '');
	if(splitNames.length > 1) {
		author = splitNames[1]+'' ''+splitNames[0];
	}
	return author;
}

var uri = doc.location.href;
var data = new Object();

// Title
var xpath = ''/html/body/span[@class="textMedium"]/table/tbody/tr/td[@class="headerBlack"]/strong//text()'';
var elmts = utilities.gatherElementsOnXPath(doc, doc, xpath, nsResolver);
var title = "";
for (var i = 0; i < elmts.length; i++) {
	var elmt = elmts[i];
	title += elmt.nodeValue;
}
if(title) {
	model.addStatement(uri, prefixDC + ''title'', title, true);
}

// Authors
var xpath = ''/html/body/span[@class="textMedium"]/table/tbody/tr/td[@class="textMedium"]/a/em'';
var elmts = utilities.gatherElementsOnXPath(doc, doc, xpath, nsResolver);
for (var i = 0; i < elmts.length; i++) {
	var elmt = elmts[i];
	
	// Dirty hack to fix highlighted words
	var xpath = ''.//text()'';
	var author = "";
	var authorElmts = utilities.gatherElementsOnXPath(doc, elmt, xpath, nsResolver);
	for (var j = 0; j < authorElmts.length; j++) {
		var authorElmt = authorElmts[j];
		author += authorElmt.nodeValue;
	}
	model.addStatement(uri, prefixDC + ''creator'', cleanAuthor(author), true);
}

// Other info
var xpath = ''/html/body/span[@class="textMedium"]/font/table/tbody/tr'';
var elmts = utilities.gatherElementsOnXPath(doc, doc, xpath, nsResolver);
for (var i = 0; i < elmts.length; i++) {
	var elmt = elmts[i];
	var field = stringTrimmer(getNode(doc, elmt, ''./TD[1]/text()[1]'', nsResolver).nodeValue).toLowerCase();
	if(field == "publication title") {
		var publication = getNode(doc, elmt, ''./TD[2]/A[1]/text()[1]'', nsResolver);
		if(publication.nodeValue) {
			model.addStatement(uri, prefixDummy + ''publication'', stringTrimmer(publication.nodeValue), true);
		}
		var place = getNode(doc, elmt, ''./TD[2]/text()[1]'', nsResolver);
		if(place.nodeValue) {
			model.addStatement(uri, prefixDummy + ''place'', stringTrimmer(place.nodeValue), true);
		}
		var date = getNode(doc, elmt, ''./TD[2]/A[2]/text()[1]'', nsResolver);		
		if(date.nodeValue) {
			model.addStatement(uri, prefixDC + ''date'', stringTrimmer(date.nodeValue), true);
		}
		var moreInfo = getNode(doc, elmt, ''./TD[2]/text()[2]'', nsResolver);
		if(moreInfo.nodeValue) {
			moreInfo = stringTrimmer(moreInfo.nodeValue);
			var parts = moreInfo.split(";\xA0");
			
			var issueRegexp = /^(\w+)\.(?: |\xA0)?(.+)$/
			var issueInfo = parts[0].split(",\xA0");
			for(j in issueInfo) {
				var m = issueRegexp.exec(issueInfo[j]);
				var info = m[1].toLowerCase();
				if(info == "vol") {
					model.addStatement(uri, prefixDummy + ''volume'', stringTrimmer(m[2]), true);
				} else if(info == "iss" || info == "no") {
					model.addStatement(uri, prefixDummy + ''number'', stringTrimmer(m[2]), true);
				}
			}
			if(parts[1] && stringTrimmer(parts[1]).substring(0, 3).toLowerCase() == "pg.") {
				var pages = getPageRange(parts[1]);
				if(pages) {
					model.addStatement(uri, prefixDummy + ''pages'', pages, true);
				}
			}
		}
	} else if(field == "source type") {
		var value = getNode(doc, elmt, ''./TD[2]/text()[1]'', nsResolver);
		if(value.nodeValue) {
			value = stringTrimmer(value.nodeValue).toLowerCase();
			
			if(value == "newspaper" || value == "periodical") {
				model.addStatement(uri, prefixRDF + "type", prefixDummy + "journal", false);
			} else {
				model.addStatement(uri, prefixRDF + "type", prefixDummy + "book", false);
			}
		}
	} else if(field == "isbn" || field == "issn" || field == "issn/isbn") {
		var value = getNode(doc, elmt, ''./TD[2]/text()[1]'', nsResolver);
		if(value) {
			var type;
			value = stringTrimmer(value.nodeValue);
			if(value.length == 10 || value.length == 13) {
				type = "ISBN";
			} else if(value.length == 8) {
				type = "ISSN";
			}
			if(type) {
				model.addStatement(uri, prefixDC + "identifier", type+" "+value, false);
			}
		}
	}
}');

INSERT INTO "scrapers" VALUES(9, NULL, NULL, 20060603002000, 'InfoTrac Scraper', 'Simon Kornblith', '^http://infotrac-college\.thomsonlearning\.com/itw/infomark/',
'if(doc.title.substring(0, 8) == "Article ") {
	return true;
}
return false;',
'var prefixRDF = ''http://www.w3.org/1999/02/22-rdf-syntax-ns#'';
var prefixDC = ''http://purl.org/dc/elements/1.1/'';
var prefixDCMI = ''http://purl.org/dc/dcmitype/'';
var prefixDummy = ''http://chnm.gmu.edu/firefox-scholar/'';

var namespace = doc.documentElement.namespaceURI;
var nsResolver = namespace ? function(prefix) {
	if (prefix == ''x'') return namespace; else return null;
} : null;

function cleanAuthor(author) {
	author = author.replace(/^[\s\.\,\/\[\]\:]+/, '''');
	author = author.replace(/[\s\,\/\[\]\:\.]+$/, '''');
	// Add period for initials
	if(author.substring(author.length-2, author.length-1) == " ") {
		author += ".";
	}
	var splitNames = author.split('', '');
	if(splitNames.length > 1) {
		author = splitNames[1]+'' ''+splitNames[0];
	}
	return author;
}

var uri = doc.location.href;

var xpath = ''/html/body//comment()'';
var elmts = utilities.gatherElementsOnXPath(doc, doc, xpath, nsResolver);
for (var i = 0; i < elmts.length; i++) {
	var elmt = elmts[i];
	var colon = elmt.nodeValue.indexOf(":");
	var field = elmt.nodeValue.substring(1, colon).toLowerCase();
	var value = elmt.nodeValue.substring(colon+1, elmt.nodeValue.length-1);
	if(field == "title") {
		model.addStatement(uri, prefixDC + "title", value, false);
	} else if(field == "journal") {
		model.addStatement(uri, prefixDummy + "publication", value, false);
	} else if(field == "pi") {
		parts = value.split(" ");
		var date = "";
		var isDate = true;
		var rdfUri;
		for(j in parts) {
			firstChar = parts[j].substring(0, 1);
			rdfUri = false;
			
			if(firstChar == "v") {
				rdfUri = prefixDummy + "volume";
			} else if(firstChar == "i") {
				rdfUri = prefixDummy + "issue";
			} else if(firstChar == "p") {
				rdfUri = prefixDummy + "pages";
				var pagesRegexp = /p(\w+)\((\w+)\)/;
				var match = pagesRegexp.exec(parts[j]);
				if(match) {
					var finalPage = parseInt(match[1])+parseInt(match[2])
					parts[j] = "p"+match[1]+"-"+finalPage.toString();
				}
			}
			
			if(rdfUri) {
				isDate = false;
				if(parts[j] != "pNA") {		// not a real page number
					var content = parts[j].substring(1);
					model.addStatement(uri, rdfUri, content, true);
				}
			} else if(isDate) {
				date += " "+parts[j];
			}
		}
		if(date != "") {
			model.addStatement(uri, prefixDC + "date", date.substring(1), false);
		}
	} else if(field == "author") {
		model.addStatement(uri, prefixDC + "creator", cleanAuthor(value), false);
	}
}
model.addStatement(uri, prefixRDF + "type", prefixDummy + "journal", false);');

INSERT INTO "scrapers" VALUES(10, NULL, NULL, 20060603002000, 'LexisNexis Scraper', 'Simon Kornblith', '^http://web\.lexis-nexis\.com/universe/document', NULL,
'var prefixRDF = ''http://www.w3.org/1999/02/22-rdf-syntax-ns#'';
var prefixDC = ''http://purl.org/dc/elements/1.1/'';
var prefixDCMI = ''http://purl.org/dc/dcmitype/'';
var prefixDummy = ''http://chnm.gmu.edu/firefox-scholar/'';

function clearTags(x) {
	x = x.replace(/<br[^>]*>/gi, "\n");
	return x.replace(/<[^>]+>/g, "");
}

var uri = doc.location.href;

var citationDataDiv;
var divs = doc.getElementsByTagName("div");
for(i in divs) {
	if(divs[i].className == "bodytext") {
		citationDataDiv = divs[i];
		break;
	}
}

centerElements = citationDataDiv.getElementsByTagName("center");
var elementParts = centerElements[0].innerHTML.split(/<br[^>]*>/gi);
model.addStatement(uri, prefixDummy + "publication", elementParts[elementParts.length-1], true);

var dateRegexp = /<br[^>]*><b>([A-Z][a-z]+)<\/b> ([0-9]+, [0-9]{4})/;
var m = dateRegexp.exec(centerElements[centerElements.length-1].innerHTML);
if(m) {
	model.addStatement(uri, prefixDC + "date", m[1]+" "+m[2], true);
} else {
	var elementParts = centerElements[centerElements.length-1].innerHTML.split(/<br[^>]*>/gi);
	model.addStatement(uri, prefixDC + "date", elementParts[1], true);
}

var cutIndex = citationDataDiv.innerHTML.indexOf("<b>BODY:</b>");
if(cutIndex < 0) {
	cutIndex = citationDataDiv.innerHTML.indexOf("<b>TEXT:</b>");
}
if(cutIndex > 0) {
	citationData = citationDataDiv.innerHTML.substring(0, cutIndex);
} else {
	citationData = citationDataDiv.innerHTML;
}

citationData = clearTags(citationData);

var headlineRegexp = /\n(?:HEADLINE|TITLE|ARTICLE): ([^\n]+)\n/;
var m = headlineRegexp.exec(citationData);
if(m) {
	model.addStatement(uri, prefixDC + "title", clearTags(m[1]), true);
}

var bylineRegexp = /\nBYLINE:  *(\w[\w\- ]+)/;
var m = bylineRegexp.exec(citationData);
if(m) {
	utilities.debugPrint(m[1].substring(0, 3).toLowerCase());
	if(m[1].substring(0, 3).toLowerCase() == "by ") {
		m[1] = m[1].substring(3);
	}
	model.addStatement(uri, prefixDC + "creator", m[1], true);
}

var authorRegexp = /\n(?:AUTHOR|NAME): ([^\n]+)\n/;
var m = authorRegexp.exec(citationData);
if(m) {
	var authors = m[1].split(/, (?:and )?/);
	for(i in authors) {
		model.addStatement(uri, prefixDC + "creator", authors[i].replace(" *", ""), true);
	}
}

model.addStatement(uri, prefixRDF + "type", prefixDummy + "journal", false);

utilities.debugPrint(citationData);');

INSERT INTO "scrapers" VALUES(11, NULL, NULL, 20060603002000, 'Aleph Scraper', 'Simon Kornblith', 'func=full-set-set.*\&format=999', NULL,
'var prefixRDF = ''http://www.w3.org/1999/02/22-rdf-syntax-ns#'';
var prefixDC = ''http://purl.org/dc/elements/1.1/'';
var prefixDCMI = ''http://purl.org/dc/dcmitype/'';
var prefixDummy = ''http://chnm.gmu.edu/firefox-scholar/'';

var uri = doc.location.href;

var newUri = uri.replace("&format=999", "&format=001");
utilities.debugPrint(newUri);

function stringTrimmer(x) {
	var x = x.replace(/^[^\w(]+/, "");
	return x.replace(/[^\w)]+$/, "");
}

utilities.loadDocument(newUri, browser, function(newBrowser) {
	newDoc = newBrowser.contentDocument;
	
	var namespace = newDoc.documentElement.namespaceURI;
	var nsResolver = namespace ? function(prefix) {
	  if (prefix == ''x'') return namespace; else return null;
	} : null;
	
	var getNode = function(doc, contextNode, xpath, nsResolver) {
	  return doc.evaluate(xpath, contextNode, nsResolver, XPathResult.ANY_TYPE,null).iterateNext();
	}
	
	var xpath = ''/html/body/table/tbody/tr[td[1][@class="td1"][@id="bold"]][td[2][@class="td1"]]'';
	var elmts = utilities.gatherElementsOnXPath(newDoc, newDoc, xpath, nsResolver);
	var record = new MARC_Record();		
	for(var i=0; i<elmts.length; i++) {
		var elmt = elmts[i];
		var field = stringTrimmer(getNode(doc, elmt, ''./TD[1]/text()[1]'', nsResolver).nodeValue);
		var value = getNode(doc, elmt, ''./TD[2]/text()[1]'', nsResolver).nodeValue;
		var value = value.replace(/\|([a-z]) /g, record.subfield_delimiter+"$1");
		
		if(field != "FMT" && field != "LDR") {
			var ind1 = "";
			var ind2 = "";
			var code = field.substring(0, 3);
			if(field.length > 3) {
				var ind1 = field.charAt(3);
				if(field.length > 4) {
					var ind2 = field.charAt(4);
				}
			}
			record.add_field(code, ind1, ind2, value);
		}
	}
	
	model = utilities.importMARCRecord(record, uri, model);
	done();
}, function() {})

wait();');

INSERT INTO "scrapers" VALUES(12, NULL, NULL, 20060603002000, 'Dynix Scraper', 'Simon Kornblith', 'ipac\.jsp\?.*uri=full=[0-9]', NULL,
'var prefixRDF = ''http://www.w3.org/1999/02/22-rdf-syntax-ns#'';
var prefixDC = ''http://purl.org/dc/elements/1.1/'';
var prefixDCMI = ''http://purl.org/dc/dcmitype/'';
var prefixDummy = ''http://chnm.gmu.edu/firefox-scholar/'';

var uri = doc.location.href;
var newUri = uri+''&fullmarc=true'';
utilities.debugPrint(newUri);

function stringTrimmer(x) {
	var x = x.replace(/^[^\w(]+/, "");
	return x.replace(/[^\w)]+$/, "");
}
	
var getNode = function(doc, contextNode, xpath, nsResolver) {
	return doc.evaluate(xpath, contextNode, nsResolver, XPathResult.ANY_TYPE,null).iterateNext();
}
	
var getNodeString = function(doc, contextNode, xpath, nsResolver) {
	var elmts = utilities.gatherElementsOnXPath(doc, contextNode, xpath, nsResolver);
	var returnVar = "";
	for(var i=0; i<elmts.length; i++) {
		returnVar += elmts[i].nodeValue;
	}
	return returnVar;
}

utilities.loadDocument(newUri, browser, function(newBrowser) {
	newDoc = newBrowser.contentDocument;
	
	var namespace = newDoc.documentElement.namespaceURI;
	var nsResolver = namespace ? function(prefix) {
	  if (prefix == ''x'') return namespace; else return null;
	} : null;
	
	var xpath = ''//form/table[@class="tableBackground"]/tbody/tr/td/table[@class="tableBackground"]/tbody/tr[td[1]/a[@class="normalBlackFont1"]]'';
	var elmts = utilities.gatherElementsOnXPath(newDoc, newDoc, xpath, nsResolver);
	var record = new MARC_Record();		
	for(var i=0; i<elmts.length; i++) {
		var elmt = elmts[i];
		var field = stringTrimmer(getNode(doc, elmt, ''./TD[1]/A[1]/text()[1]'', nsResolver).nodeValue);
		var value = getNodeString(doc, elmt, ''./TD[2]/TABLE[1]/TBODY[1]/TR[1]/TD[1]/A[1]//text()'', nsResolver);
		value = value.replace(/\$([a-z]) /g, record.subfield_delimiter+"$1");
		
		if(field != "FMT" && field != "LDR") {
			var ind1 = "";
			var ind2 = "";
			var valRegexp = /^([0-9])([0-9])? (.*)$/;
			var m = valRegexp.exec(value);
			if(m) {
				ind1 = m[1];
				if(ind2) {
					ind2 = m[2]
				}
				value = m[3];
			}
			record.add_field(field, ind1, ind2, value);
		}
	}
	
	model = utilities.importMARCRecord(record, uri, model);
	done();
}, function() {})

wait();');

INSERT INTO "scrapers" VALUES(13, NULL, NULL, 20060603002000, 'VTLS Scraper', 'Simon Kornblith', 'chameleon\?.*function=(?:CARDSCR|INITREQ)', NULL,
'var prefixRDF = ''http://www.w3.org/1999/02/22-rdf-syntax-ns#'';
var prefixDC = ''http://purl.org/dc/elements/1.1/'';
var prefixDCMI = ''http://purl.org/dc/dcmitype/'';
var prefixDummy = ''http://chnm.gmu.edu/firefox-scholar/'';

var uri = doc.location.href;
var newUri = uri.replace(/function=[A-Z]{7}/, "function=MARCSCR");
utilities.debugPrint(newUri);
	
var getNode = function(doc, contextNode, xpath, nsResolver) {
	return doc.evaluate(xpath, contextNode, nsResolver, XPathResult.ANY_TYPE,null).iterateNext();
}

utilities.loadDocument(newUri, browser, function(newBrowser) {
	newDoc = newBrowser.contentDocument;
	
	var namespace = newDoc.documentElement.namespaceURI;
	var nsResolver = namespace ? function(prefix) {
	  if (prefix == ''x'') return namespace; else return null;
	} : null;
	
	var xpath = ''//table[@class="outertable"]/tbody/tr[td[4]]'';
	var elmts = utilities.gatherElementsOnXPath(newDoc, newDoc, xpath, nsResolver);
	var record = new MARC_Record();		
	for(var i=0; i<elmts.length; i++) {
		var elmt = elmts[i];
		var field = getNode(doc, elmt, ''./TD[1]/text()[1]'', nsResolver).nodeValue;
		var ind1 = getNode(doc, elmt, ''./TD[2]/text()[1]'', nsResolver).nodeValue;
		var ind2 = getNode(doc, elmt, ''./TD[3]/text()[1]'', nsResolver).nodeValue;
		var value = getNode(doc, elmt, ''./TD[4]/text()[1]'', nsResolver).nodeValue;
		value = value.replace(/\\([a-z]) /g, record.subfield_delimiter+"$1");
		
		record.add_field(field, ind1, ind2, value);
	}
	
	model = utilities.importMARCRecord(record, uri, model);
	done();
}, function() {})

wait();');

INSERT INTO "scrapers" VALUES(14, NULL, NULL, 20060603002000, 'DRA Scraper', 'Simon Kornblith', '/web2/tramp2\.exe/(?:see\_record/|authority\_hits/|goto/.*\?.*screen=Record\.html)',
'if(doc.location.href.indexOf("authority_hits") > 0) {
	var body = doc.getElementsByTagName("body");
	if(body[0].innerHTML.indexOf("ISBN") < 0) {
		return false;
	}
}
return true;',
'var prefixRDF = ''http://www.w3.org/1999/02/22-rdf-syntax-ns#'';
var prefixDC = ''http://purl.org/dc/elements/1.1/'';
var prefixDCMI = ''http://purl.org/dc/dcmitype/'';
var prefixDummy = ''http://chnm.gmu.edu/firefox-scholar/'';

var uri = doc.location.href;
var uriRegexp = /^(https?:\/\/.*\/web2\/tramp2\.exe\/)(?:goto|see\_record|authority\_hits)(\/.*)\?(?:screen=Record\.html\&)?(.*)$/i;
var m = uriRegexp.exec(uri);
if(uri.indexOf("authority_hits") < 0) {
	var newUri = m[1]+"download_record"+m[2]+"/RECORD.MRC?format=marc&"+m[3];
} else {
	var newUri = m[1]+"download_record"+m[2]+"/RECORD.MRC?format=marc";
}

utilities.debugPrint(newUri);

utilities.HTTPUtilities.doGet(newUri, null, function(text) {
	var record = new MARC_Record();
	record.load(text, "binary");
	model = utilities.importMARCRecord(record, uri, model);
	done();
})
wait();');


INSERT INTO "scrapers" VALUES(15, NULL, NULL, 20060603002000, 'GEAC Scraper', 'Simon Kornblith', '/(?:Geac)?FETCH[\:\?].*[&:]next=html/(?:record\.html|geacnffull\.html)', NULL,
'var prefixRDF = ''http://www.w3.org/1999/02/22-rdf-syntax-ns#'';
var prefixDC = ''http://purl.org/dc/elements/1.1/'';
var prefixDCMI = ''http://purl.org/dc/dcmitype/'';
var prefixDummy = ''http://chnm.gmu.edu/firefox-scholar/'';

var uri = doc.location.href;
var newUri = uri.replace(/([:&])next=html\/geacnffull.html/, "$1next=html/marc.html");
newUri = newUri.replace(/([:&])next=html\/record.html/, "$1next=html/marc.html");
	
var getNode = function(doc, contextNode, xpath, nsResolver) {
	return doc.evaluate(xpath, contextNode, nsResolver, XPathResult.ANY_TYPE,null).iterateNext();
}

utilities.loadDocument(newUri, browser, function(newBrowser) {
	newDoc = newBrowser.contentDocument;
	
	var namespace = newDoc.documentElement.namespaceURI;
	var nsResolver = namespace ? function(prefix) {
	  if (prefix == ''x'') return namespace; else return null;
	} : null;
	
	var record = new MARC_Record();
	
	var elmts = utilities.gatherElementsOnXPath(newDoc, newDoc, ''//pre/text()'', nsResolver);
	var tag, ind1, ind2, content;
	
	for(var i=0; i<elmts.length; i++) {
		var line = elmts[i].nodeValue;
		
		if(line.substring(0, 6) == "       ") {
			content += " "+line.substring(6);
			continue;
		} else {
			if(tag) {
				record.add_field(tag, ind1, ind2, content);
			}
		}
		
		line = line.replace(/\xA0/g," "); // nbsp
		line = line.replace(/_/g," ");
		line = line.replace(/\t/g,"");
		
		tag = line.substring(0, 3);
		if(parseInt(tag) > 10) {
			ind1 = line.substring(4, 5);
			ind2 = line.substring(5, 6);
			content = line.substring(7);
			content = content.replace(/\$([a-z])(?: |$)/g, record.subfield_delimiter+"$1");
		} else {
			ind1 = "";
			ind2 = "";
			content = line.substring(4);
		}
		
	}
	
	model = utilities.importMARCRecord(record, uri, model);
	done();
}, function() {});

wait();');

INSERT INTO "scrapers" VALUES(16, NULL, NULL, 20060603002000, 'SIRSI -2003 Scraper', 'Simon Kornblith', '/uhtbin/cgisirsi',
'var namespace = doc.documentElement.namespaceURI;
var nsResolver = namespace ? function(prefix) {
	if (prefix == ''x'') return namespace; else return null;
} : null;

var elmts = utilities.gatherElementsOnXPath(doc, doc, ''/html/body/form/p/text()[1]'', nsResolver);
for(i in elmts) {
	utilities.debugPrint(elmts[i].nodeValue);
	if(elmts[i].nodeValue == "\n\nViewing record\n") {
		return true;
	}
}
return false;',
'var prefixRDF = ''http://www.w3.org/1999/02/22-rdf-syntax-ns#'';
var prefixDC = ''http://purl.org/dc/elements/1.1/'';
var prefixDCMI = ''http://purl.org/dc/dcmitype/'';
var prefixDummy = ''http://chnm.gmu.edu/firefox-scholar/'';

var namespace = doc.documentElement.namespaceURI;
var nsResolver = namespace ? function(prefix) {
	if (prefix == ''x'') return namespace; else return null;
} : null;

var getNode = function(doc, contextNode, xpath, nsResolver) {
	return doc.evaluate(xpath, contextNode, nsResolver, XPathResult.ANY_TYPE,null).iterateNext();
}

var uri = doc.location.href;
var uriRegexp = /^(.*)(\/[0-9]+)$/;
var m = uriRegexp.exec(uri);
var newUri = m[1]+"/40";
utilities.debugPrint(newUri);

var elmts = utilities.gatherElementsOnXPath(doc, doc, ''/html/body/form/p'', nsResolver);
for(i in elmts) {
	var elmt = elmts[i];
	var initialText = getNode(doc, elmt, ''./text()[1]'', nsResolver);
	if(initialText.nodeValue == "\n\nViewing record\n") {
		var recNumber = getNode(doc, elmt, ''./b[1]/text()[1]'', nsResolver).nodeValue;
	}
}

utilities.HTTPUtilities.doPost(newUri, ''marks=''+recNumber+''&shadow=NO&format=FLAT+ASCII&sort=TITLE&vopt_elst=ALL&library=ALL&display_rule=ASCENDING&duedate_code=l&holdcount_code=t&DOWNLOAD_x=22&DOWNLOAD_y=12&address=&form_type='', null, function(text) {
	var texts = text.split("<PRE>");
	texts = texts[1].split("</PRE>");
	text = texts[0];
	var lines = text.split("\n");
	
	var record = new MARC_Record();
	
	var tag, ind1, ind2, content;
	for(var i=0; i<lines.length; i++) {
		var line = lines[i];
		
		if(line.substr(0, 1) == "." && line.substr(4,2) == ". ") {
			if(tag) {
				content = content.replace(/\|([a-z])/g, record.subfield_delimiter+"$1");
				record.add_field(tag, ind1, ind2, content);
			}
		} else {
			content += " "+line.substring(6);
			continue;
		}
		
		tag = line.substr(1, 3);
		
		if(parseInt(tag) > 10) {
			ind1 = line.substr(6, 1);
			ind2 = line.substr(7, 1);
			content = line.substr(8);
		} else {
			ind1 = "";
			ind2 = "";
			content = line.substring(6);
		}
	}

	model = utilities.importMARCRecord(record, uri, model);
	done();
})
wait();');

INSERT INTO "scrapers" VALUES(17, NULL, NULL, 20060603002000, 'TLC/YouSeeMore Scraper', 'Simon Kornblith', 'TLCScripts/interpac\.dll\?.*LabelDisplay.*RecordNumber=[0-9]', NULL,
'var prefixRDF = ''http://www.w3.org/1999/02/22-rdf-syntax-ns#'';
var prefixDC = ''http://purl.org/dc/elements/1.1/'';
var prefixDCMI = ''http://purl.org/dc/dcmitype/'';
var prefixDummy = ''http://chnm.gmu.edu/firefox-scholar/'';

var namespace = doc.documentElement.namespaceURI;
var nsResolver = namespace ? function(prefix) {
	if (prefix == ''x'') return namespace; else return null;
} : null;

var getNode = function(doc, contextNode, xpath, nsResolver) {
	return doc.evaluate(xpath, contextNode, nsResolver, XPathResult.ANY_TYPE,null).iterateNext();
}

var uri = doc.location.href;
var newUri = uri.replace("LabelDisplay", "MARCDisplay");
utilities.debugPrint(newUri);

utilities.loadDocument(newUri, browser, function(newBrowser) {
	newDoc = newBrowser.contentDocument;
	
	var namespace = newDoc.documentElement.namespaceURI;
	var nsResolver = namespace ? function(prefix) {
	  if (prefix == ''x'') return namespace; else return null;
	} : null;
	
	var record = new MARC_Record();
	
	var elmts = utilities.gatherElementsOnXPath(newDoc, newDoc, ''/html/body/table/tbody/tr[td[4]]'', nsResolver);
	var tag, ind1, ind2, content;
	
	for(var i=0; i<elmts.length; i++) {
		var elmt = elmts[i];
		
		tag = getNode(newDoc, elmt, ''./td[2]/tt[1]/text()[1]'', nsResolver).nodeValue;
		var inds = getNode(newDoc, elmt, ''./td[3]/tt[1]/text()[1]'', nsResolver).nodeValue;
		
		tag = tag.replace(/[\r\n]/g, "");
		if(tag.length == 1) {
			tag = "00"+tag;
		} else if(tag.length == 2) {
			tag = "0"+tag;
		}
		inds = inds.replace(/[\r\n]/g, "");
		
		// Get indicators, fix possible problems with &nbsp;s
		ind1 = inds.substr(0, 1);
		ind2 = inds.substr(1, 1);
		if(ind1 == "\xA0") {
			ind1 = "";
		}
		if(ind2 == "\xA0") {
			ind2 = "";
		}
		
		var children = utilities.gatherElementsOnXPath(newDoc, elmt, ''./td[4]/tt[1]//text()'', nsResolver);
		content = "";
		if(children.length == 1) {
			content = children[0].nodeValue;
		} else {
			for(var j=0; j<children.length; j+=2) {
				var subfield = children[j].nodeValue.substr(1, 1);
				var fieldContent = children[j+1].nodeValue;
				content += record.subfield_delimiter+subfield+fieldContent;
			}
		}
		
		record.add_field(tag, ind1, ind2, content);
		utilities.debugPrint("tag:"+tag+" ind1:"+ind1+" ind2:"+ind2+" content:"+content);
	}
	
	model = utilities.importMARCRecord(record, uri, model);
	done();
}, function() {});

wait();');

INSERT INTO "scrapers" VALUES(18, NULL, NULL, 20060603002000, 'Project MUSE Scraper', 'Simon Kornblith', '^http://muse.jhu.edu/journals/[^/]+/[^/]+/[^/]+.html$', NULL, 'var prefixRDF = ''http://www.w3.org/1999/02/22-rdf-syntax-ns#'';
var prefixDC = ''http://purl.org/dc/elements/1.1/'';
var prefixDCMI = ''http://purl.org/dc/dcmitype/'';
var prefixDummy = ''http://chnm.gmu.edu/firefox-scholar/'';

var namespace = doc.documentElement.namespaceURI;
var nsResolver = namespace ? function(prefix) {
	if (prefix == ''x'') return namespace; else return null;
} : null;

function numbersOnly(text) {
	return text.replace(/[^0-9]/g, "");
}

var uri = doc.location.href;

var elmts = utilities.gatherElementsOnXPath(doc, doc, ''//comment()'', nsResolver);
for(i in elmts) {
	if(elmts[i].nodeValue.substr(0, 10) == "HeaderData") {
		var headerRegexp = /HeaderData((?:.|\n)*)\#\#EndHeaders/i
		var m = headerRegexp.exec(elmts[i].nodeValue);
		var headerData = m[1];
	}
}

// Use E4X rather than DOM/XPath, because the Mozilla gods have decided not to
// expose DOM/XPath to sandboxed scripts
var newDOM = new XML(headerData);

function mapDOM(path, rdfUri) {
	if(newDOM.header[path]) {
		model.addStatement(uri, rdfUri, newDOM[path].text(), true);
	}
}

mapDOM("journal", prefixDummy + "publication");
mapDOM("issn", prefixDummy + "publication", numbersOnly);
mapDOM("volume", prefixDummy + "volume");
mapDOM("issue", prefixDummy + "issue");
mapDOM("year", prefixDummy + "year");
mapDOM("pubdate", prefixDC + "date");
mapDOM("doctitle", prefixDC + "title");

// Do pages
var fpage = newDOM.fpage.text();
var lpage = newDOM.lpage.text();
if(fpage) {
	var pages = fpage;
	if(lpage) {
		pages += "-"+lpage;
	}
	model.addStatement(uri, prefixDummy + "pages", pages, true);
}

// Do authors
var elmts = newDOM.docauthor;
for(i in elmts) {
	var fname = elmts[i].fname.text();
	var surname = elmts[i].surname.text();
	model.addStatement(uri, prefixDC + "creator", fname+" "+surname, true);
}

model.addStatement(uri, prefixRDF + "type", prefixDummy + "journal", false);');