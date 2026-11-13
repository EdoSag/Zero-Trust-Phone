/// Countries by international calling code, for the "country and local
/// time" hint on the dialpad (P16). Names in English and Hebrew; time
/// zones are IANA names, the main ones first, so a country spread over
/// several zones shows the range of its times.
///
/// Kept on the phone: nothing is looked up online.
class Country {
  const Country(this.code, this.iso, this.en, this.he, this.zones);

  /// The calling code without "+", e.g. "49". Some are longer than the
  /// country's own code because they pick out one area ("1876" Jamaica,
  /// "77" Kazakhstan).
  final String code;

  /// ISO 3166 two-letter code, upper case.
  final String iso;
  final String en;
  final String he;
  final List<String> zones;

  /// The flag as an emoji (two regional indicator letters).
  String get flag => String.fromCharCodes(<int>[
    for (final int c in iso.codeUnits) 0x1F1E6 + c - 0x41,
  ]);

  String name(String languageCode) => languageCode == 'he' ? he : en;
}

/// North American (+1) area codes that are not the United States.
final Map<String, String> nanpAreas = <String, String>{
  // Canada.
  for (final String a in const <String>[
    '204', '226', '236', '249', '250', '263', '289', '306', '343', '354', //
    '365', '367', '368', '382', '403', '416', '418', '428', '431', '437',
    '438', '450', '468', '474', '506', '514', '519', '548', '579', '581',
    '584', '587', '604', '613', '639', '647', '672', '683', '705', '709',
    '742', '753', '778', '780', '782', '807', '819', '825', '867', '873',
    '879', '902', '905',
  ])
    a: 'CA',
  '242': 'BS', '246': 'BB', '264': 'AI', '268': 'AG', '284': 'VG', //
  '340': 'VI', '345': 'KY', '441': 'BM', '473': 'GD', '649': 'TC',
  '658': 'JM', '664': 'MS', '670': 'MP', '671': 'GU', '684': 'AS',
  '721': 'SX', '758': 'LC', '767': 'DM', '784': 'VC', '787': 'PR',
  '809': 'DO', '829': 'DO', '849': 'DO', '868': 'TT', '869': 'KN',
  '876': 'JM', '939': 'PR',
};

/// Canadian zones by area code where they aren't Eastern.
const Map<String, List<String>> canadaZones = <String, List<String>>{
  '204': <String>['America/Winnipeg'],
  '431': <String>['America/Winnipeg'],
  '306': <String>['America/Regina'],
  '639': <String>['America/Regina'],
  '403': <String>['America/Edmonton'],
  '587': <String>['America/Edmonton'],
  '780': <String>['America/Edmonton'],
  '825': <String>['America/Edmonton'],
  '368': <String>['America/Edmonton'],
  '236': <String>['America/Vancouver'],
  '250': <String>['America/Vancouver'],
  '604': <String>['America/Vancouver'],
  '672': <String>['America/Vancouver'],
  '778': <String>['America/Vancouver'],
  '257': <String>['America/Vancouver'],
  '506': <String>['America/Halifax'],
  '782': <String>['America/Halifax'],
  '902': <String>['America/Halifax'],
  '709': <String>['America/St_Johns'],
  '879': <String>['America/St_Johns'],
  '867': <String>['America/Whitehorse', 'America/Yellowknife'],
};

const List<String> usZones = <String>[
  'America/New_York',
  'America/Chicago',
  'America/Denver',
  'America/Los_Angeles',
];

const List<Country> countries = <Country>[
  Country('1', 'US', 'United States', 'ארצות הברית', usZones),
  Country('1', 'CA', 'Canada', 'קנדה', <String>[
    'America/Toronto',
    'America/Winnipeg',
    'America/Edmonton',
    'America/Vancouver',
  ]),
  Country('1', 'BS', 'Bahamas', 'איי בהאמה', <String>['America/Nassau']),
  Country('1', 'BB', 'Barbados', 'ברבדוס', <String>['America/Barbados']),
  Country('1', 'AI', 'Anguilla', 'אנגווילה', <String>['America/Anguilla']),
  Country('1', 'AG', 'Antigua and Barbuda', 'אנטיגואה וברבודה', <String>[
    'America/Antigua',
  ]),
  Country('1', 'VG', 'British Virgin Islands', 'איי הבתולה הבריטיים', <String>[
    'America/Tortola',
  ]),
  Country('1', 'VI', 'US Virgin Islands', 'איי הבתולה של ארצות הברית', <String>[
    'America/St_Thomas',
  ]),
  Country('1', 'KY', 'Cayman Islands', 'איי קיימן', <String>['America/Cayman']),
  Country('1', 'BM', 'Bermuda', 'ברמודה', <String>['Atlantic/Bermuda']),
  Country('1', 'GD', 'Grenada', 'גרנדה', <String>['America/Grenada']),
  Country('1', 'TC', 'Turks and Caicos Islands', 'איי טרקס וקייקוס', <String>[
    'America/Grand_Turk',
  ]),
  Country('1', 'JM', 'Jamaica', "ג'מייקה", <String>['America/Jamaica']),
  Country('1', 'MS', 'Montserrat', 'מונסראט', <String>['America/Montserrat']),
  Country(
    '1',
    'MP',
    'Northern Mariana Islands',
    'איי מריאנה הצפוניים',
    <String>['Pacific/Saipan'],
  ),
  Country('1', 'GU', 'Guam', 'גואם', <String>['Pacific/Guam']),
  Country('1', 'AS', 'American Samoa', 'סמואה האמריקנית', <String>[
    'Pacific/Pago_Pago',
  ]),
  Country('1', 'SX', 'Sint Maarten', 'סינט מארטן', <String>[
    'America/Lower_Princes',
  ]),
  Country('1', 'LC', 'Saint Lucia', 'סנט לוסיה', <String>['America/St_Lucia']),
  Country('1', 'DM', 'Dominica', 'דומיניקה', <String>['America/Dominica']),
  Country(
    '1',
    'VC',
    'Saint Vincent and the Grenadines',
    'סנט וינסנט והגרנדינים',
    <String>['America/St_Vincent'],
  ),
  Country('1', 'PR', 'Puerto Rico', 'פוארטו ריקו', <String>[
    'America/Puerto_Rico',
  ]),
  Country('1', 'DO', 'Dominican Republic', 'הרפובליקה הדומיניקנית', <String>[
    'America/Santo_Domingo',
  ]),
  Country('1', 'TT', 'Trinidad and Tobago', 'טרינידד וטובגו', <String>[
    'America/Port_of_Spain',
  ]),
  Country('1', 'KN', 'Saint Kitts and Nevis', 'סנט קיטס ונוויס', <String>[
    'America/St_Kitts',
  ]),
  Country('7', 'RU', 'Russia', 'רוסיה', <String>[
    'Europe/Kaliningrad',
    'Europe/Moscow',
    'Europe/Samara',
    'Asia/Yekaterinburg',
    'Asia/Omsk',
    'Asia/Novosibirsk',
    'Asia/Krasnoyarsk',
    'Asia/Irkutsk',
    'Asia/Yakutsk',
    'Asia/Vladivostok',
    'Asia/Magadan',
    'Asia/Kamchatka',
  ]),
  Country('76', 'KZ', 'Kazakhstan', 'קזחסטן', <String>['Asia/Almaty']),
  Country('77', 'KZ', 'Kazakhstan', 'קזחסטן', <String>['Asia/Almaty']),
  Country('20', 'EG', 'Egypt', 'מצרים', <String>['Africa/Cairo']),
  Country('27', 'ZA', 'South Africa', 'דרום אפריקה', <String>[
    'Africa/Johannesburg',
  ]),
  Country('30', 'GR', 'Greece', 'יוון', <String>['Europe/Athens']),
  Country('31', 'NL', 'Netherlands', 'הולנד', <String>['Europe/Amsterdam']),
  Country('32', 'BE', 'Belgium', 'בלגיה', <String>['Europe/Brussels']),
  Country('33', 'FR', 'France', 'צרפת', <String>['Europe/Paris']),
  Country('34', 'ES', 'Spain', 'ספרד', <String>['Europe/Madrid']),
  Country('36', 'HU', 'Hungary', 'הונגריה', <String>['Europe/Budapest']),
  Country('39', 'IT', 'Italy', 'איטליה', <String>['Europe/Rome']),
  Country('40', 'RO', 'Romania', 'רומניה', <String>['Europe/Bucharest']),
  Country('41', 'CH', 'Switzerland', 'שווייץ', <String>['Europe/Zurich']),
  Country('43', 'AT', 'Austria', 'אוסטריה', <String>['Europe/Vienna']),
  Country('44', 'GB', 'United Kingdom', 'בריטניה', <String>['Europe/London']),
  Country('45', 'DK', 'Denmark', 'דנמרק', <String>['Europe/Copenhagen']),
  Country('46', 'SE', 'Sweden', 'שוודיה', <String>['Europe/Stockholm']),
  Country('47', 'NO', 'Norway', 'נורווגיה', <String>['Europe/Oslo']),
  Country('48', 'PL', 'Poland', 'פולין', <String>['Europe/Warsaw']),
  Country('49', 'DE', 'Germany', 'גרמניה', <String>['Europe/Berlin']),
  Country('51', 'PE', 'Peru', 'פרו', <String>['America/Lima']),
  Country('52', 'MX', 'Mexico', 'מקסיקו', <String>[
    'America/Mexico_City',
    'America/Cancun',
    'America/Chihuahua',
    'America/Tijuana',
  ]),
  Country('53', 'CU', 'Cuba', 'קובה', <String>['America/Havana']),
  Country('54', 'AR', 'Argentina', 'ארגנטינה', <String>[
    'America/Argentina/Buenos_Aires',
  ]),
  Country('55', 'BR', 'Brazil', 'ברזיל', <String>[
    'America/Sao_Paulo',
    'America/Manaus',
    'America/Rio_Branco',
    'America/Noronha',
  ]),
  Country('56', 'CL', 'Chile', "צ'ילה", <String>['America/Santiago']),
  Country('57', 'CO', 'Colombia', 'קולומביה', <String>['America/Bogota']),
  Country('58', 'VE', 'Venezuela', 'ונצואלה', <String>['America/Caracas']),
  Country('60', 'MY', 'Malaysia', 'מלזיה', <String>['Asia/Kuala_Lumpur']),
  Country('61', 'AU', 'Australia', 'אוסטרליה', <String>[
    'Australia/Sydney',
    'Australia/Brisbane',
    'Australia/Adelaide',
    'Australia/Darwin',
    'Australia/Perth',
  ]),
  Country('62', 'ID', 'Indonesia', 'אינדונזיה', <String>[
    'Asia/Jakarta',
    'Asia/Makassar',
    'Asia/Jayapura',
  ]),
  Country('63', 'PH', 'Philippines', 'הפיליפינים', <String>['Asia/Manila']),
  Country('64', 'NZ', 'New Zealand', 'ניו זילנד', <String>['Pacific/Auckland']),
  Country('65', 'SG', 'Singapore', 'סינגפור', <String>['Asia/Singapore']),
  Country('66', 'TH', 'Thailand', 'תאילנד', <String>['Asia/Bangkok']),
  Country('81', 'JP', 'Japan', 'יפן', <String>['Asia/Tokyo']),
  Country('82', 'KR', 'South Korea', 'דרום קוריאה', <String>['Asia/Seoul']),
  Country('84', 'VN', 'Vietnam', 'וייטנאם', <String>['Asia/Ho_Chi_Minh']),
  Country('86', 'CN', 'China', 'סין', <String>['Asia/Shanghai']),
  Country('90', 'TR', 'Turkey', 'טורקיה', <String>['Europe/Istanbul']),
  Country('91', 'IN', 'India', 'הודו', <String>['Asia/Kolkata']),
  Country('92', 'PK', 'Pakistan', 'פקיסטן', <String>['Asia/Karachi']),
  Country('93', 'AF', 'Afghanistan', 'אפגניסטן', <String>['Asia/Kabul']),
  Country('94', 'LK', 'Sri Lanka', 'סרי לנקה', <String>['Asia/Colombo']),
  Country('95', 'MM', 'Myanmar', 'מיאנמר', <String>['Asia/Yangon']),
  Country('98', 'IR', 'Iran', 'איראן', <String>['Asia/Tehran']),
  Country('211', 'SS', 'South Sudan', 'דרום סודאן', <String>['Africa/Juba']),
  Country('212', 'MA', 'Morocco', 'מרוקו', <String>['Africa/Casablanca']),
  Country('213', 'DZ', 'Algeria', "אלג'יריה", <String>['Africa/Algiers']),
  Country('216', 'TN', 'Tunisia', 'תוניסיה', <String>['Africa/Tunis']),
  Country('218', 'LY', 'Libya', 'לוב', <String>['Africa/Tripoli']),
  Country('220', 'GM', 'Gambia', 'גמביה', <String>['Africa/Banjul']),
  Country('221', 'SN', 'Senegal', 'סנגל', <String>['Africa/Dakar']),
  Country('222', 'MR', 'Mauritania', 'מאוריטניה', <String>[
    'Africa/Nouakchott',
  ]),
  Country('223', 'ML', 'Mali', 'מאלי', <String>['Africa/Bamako']),
  Country('224', 'GN', 'Guinea', 'גינאה', <String>['Africa/Conakry']),
  Country('225', 'CI', "Côte d'Ivoire", 'חוף השנהב', <String>[
    'Africa/Abidjan',
  ]),
  Country('226', 'BF', 'Burkina Faso', 'בורקינה פאסו', <String>[
    'Africa/Ouagadougou',
  ]),
  Country('227', 'NE', 'Niger', "ניז'ר", <String>['Africa/Niamey']),
  Country('228', 'TG', 'Togo', 'טוגו', <String>['Africa/Lome']),
  Country('229', 'BJ', 'Benin', 'בנין', <String>['Africa/Porto-Novo']),
  Country('230', 'MU', 'Mauritius', 'מאוריציוס', <String>['Indian/Mauritius']),
  Country('231', 'LR', 'Liberia', 'ליבריה', <String>['Africa/Monrovia']),
  Country('232', 'SL', 'Sierra Leone', 'סיירה לאון', <String>[
    'Africa/Freetown',
  ]),
  Country('233', 'GH', 'Ghana', 'גאנה', <String>['Africa/Accra']),
  Country('234', 'NG', 'Nigeria', 'ניגריה', <String>['Africa/Lagos']),
  Country('235', 'TD', 'Chad', "צ'אד", <String>['Africa/Ndjamena']),
  Country(
    '236',
    'CF',
    'Central African Republic',
    'הרפובליקה המרכז אפריקאית',
    <String>['Africa/Bangui'],
  ),
  Country('237', 'CM', 'Cameroon', 'קמרון', <String>['Africa/Douala']),
  Country('238', 'CV', 'Cape Verde', 'כף ורדה', <String>[
    'Atlantic/Cape_Verde',
  ]),
  Country('239', 'ST', 'São Tomé and Príncipe', 'סאו טומה ופרינסיפה', <String>[
    'Africa/Sao_Tome',
  ]),
  Country('240', 'GQ', 'Equatorial Guinea', 'גינאה המשוונית', <String>[
    'Africa/Malabo',
  ]),
  Country('241', 'GA', 'Gabon', 'גבון', <String>['Africa/Libreville']),
  Country('242', 'CG', 'Congo', 'קונגו', <String>['Africa/Brazzaville']),
  Country('243', 'CD', 'DR Congo', 'הרפובליקה הדמוקרטית של קונגו', <String>[
    'Africa/Kinshasa',
    'Africa/Lubumbashi',
  ]),
  Country('244', 'AO', 'Angola', 'אנגולה', <String>['Africa/Luanda']),
  Country('245', 'GW', 'Guinea-Bissau', 'גינאה ביסאו', <String>[
    'Africa/Bissau',
  ]),
  Country('248', 'SC', 'Seychelles', 'סיישל', <String>['Indian/Mahe']),
  Country('249', 'SD', 'Sudan', 'סודאן', <String>['Africa/Khartoum']),
  Country('250', 'RW', 'Rwanda', 'רואנדה', <String>['Africa/Kigali']),
  Country('251', 'ET', 'Ethiopia', 'אתיופיה', <String>['Africa/Addis_Ababa']),
  Country('252', 'SO', 'Somalia', 'סומליה', <String>['Africa/Mogadishu']),
  Country('253', 'DJ', 'Djibouti', "ג'יבוטי", <String>['Africa/Djibouti']),
  Country('254', 'KE', 'Kenya', 'קניה', <String>['Africa/Nairobi']),
  Country('255', 'TZ', 'Tanzania', 'טנזניה', <String>['Africa/Dar_es_Salaam']),
  Country('256', 'UG', 'Uganda', 'אוגנדה', <String>['Africa/Kampala']),
  Country('257', 'BI', 'Burundi', 'בורונדי', <String>['Africa/Bujumbura']),
  Country('258', 'MZ', 'Mozambique', 'מוזמביק', <String>['Africa/Maputo']),
  Country('260', 'ZM', 'Zambia', 'זמביה', <String>['Africa/Lusaka']),
  Country('261', 'MG', 'Madagascar', 'מדגסקר', <String>['Indian/Antananarivo']),
  Country('262', 'RE', 'Réunion', 'ראוניון', <String>['Indian/Reunion']),
  Country('263', 'ZW', 'Zimbabwe', 'זימבבואה', <String>['Africa/Harare']),
  Country('264', 'NA', 'Namibia', 'נמיביה', <String>['Africa/Windhoek']),
  Country('265', 'MW', 'Malawi', 'מלאווי', <String>['Africa/Blantyre']),
  Country('266', 'LS', 'Lesotho', 'לסוטו', <String>['Africa/Maseru']),
  Country('267', 'BW', 'Botswana', 'בוטסואנה', <String>['Africa/Gaborone']),
  Country('268', 'SZ', 'Eswatini', 'אסוואטיני', <String>['Africa/Mbabane']),
  Country('269', 'KM', 'Comoros', 'קומורו', <String>['Indian/Comoro']),
  Country('290', 'SH', 'Saint Helena', 'סנט הלנה', <String>[
    'Atlantic/St_Helena',
  ]),
  Country('291', 'ER', 'Eritrea', 'אריתריאה', <String>['Africa/Asmara']),
  Country('297', 'AW', 'Aruba', 'ארובה', <String>['America/Aruba']),
  Country('298', 'FO', 'Faroe Islands', 'איי פארו', <String>['Atlantic/Faroe']),
  Country('299', 'GL', 'Greenland', 'גרינלנד', <String>['America/Nuuk']),
  Country('350', 'GI', 'Gibraltar', 'גיברלטר', <String>['Europe/Gibraltar']),
  Country('351', 'PT', 'Portugal', 'פורטוגל', <String>['Europe/Lisbon']),
  Country('352', 'LU', 'Luxembourg', 'לוקסמבורג', <String>[
    'Europe/Luxembourg',
  ]),
  Country('353', 'IE', 'Ireland', 'אירלנד', <String>['Europe/Dublin']),
  Country('354', 'IS', 'Iceland', 'איסלנד', <String>['Atlantic/Reykjavik']),
  Country('355', 'AL', 'Albania', 'אלבניה', <String>['Europe/Tirane']),
  Country('356', 'MT', 'Malta', 'מלטה', <String>['Europe/Malta']),
  Country('357', 'CY', 'Cyprus', 'קפריסין', <String>['Asia/Nicosia']),
  Country('358', 'FI', 'Finland', 'פינלנד', <String>['Europe/Helsinki']),
  Country('359', 'BG', 'Bulgaria', 'בולגריה', <String>['Europe/Sofia']),
  Country('370', 'LT', 'Lithuania', 'ליטא', <String>['Europe/Vilnius']),
  Country('371', 'LV', 'Latvia', 'לטביה', <String>['Europe/Riga']),
  Country('372', 'EE', 'Estonia', 'אסטוניה', <String>['Europe/Tallinn']),
  Country('373', 'MD', 'Moldova', 'מולדובה', <String>['Europe/Chisinau']),
  Country('374', 'AM', 'Armenia', 'ארמניה', <String>['Asia/Yerevan']),
  Country('375', 'BY', 'Belarus', 'בלארוס', <String>['Europe/Minsk']),
  Country('376', 'AD', 'Andorra', 'אנדורה', <String>['Europe/Andorra']),
  Country('377', 'MC', 'Monaco', 'מונקו', <String>['Europe/Monaco']),
  Country('378', 'SM', 'San Marino', 'סן מרינו', <String>['Europe/San_Marino']),
  Country('380', 'UA', 'Ukraine', 'אוקראינה', <String>['Europe/Kyiv']),
  Country('381', 'RS', 'Serbia', 'סרביה', <String>['Europe/Belgrade']),
  Country('382', 'ME', 'Montenegro', 'מונטנגרו', <String>['Europe/Podgorica']),
  Country('383', 'XK', 'Kosovo', 'קוסובו', <String>['Europe/Belgrade']),
  Country('385', 'HR', 'Croatia', 'קרואטיה', <String>['Europe/Zagreb']),
  Country('386', 'SI', 'Slovenia', 'סלובניה', <String>['Europe/Ljubljana']),
  Country('387', 'BA', 'Bosnia and Herzegovina', 'בוסניה והרצגובינה', <String>[
    'Europe/Sarajevo',
  ]),
  Country('389', 'MK', 'North Macedonia', 'צפון מקדוניה', <String>[
    'Europe/Skopje',
  ]),
  Country('420', 'CZ', 'Czechia', "צ'כיה", <String>['Europe/Prague']),
  Country('421', 'SK', 'Slovakia', 'סלובקיה', <String>['Europe/Bratislava']),
  Country('423', 'LI', 'Liechtenstein', 'ליכטנשטיין', <String>['Europe/Vaduz']),
  Country('500', 'FK', 'Falkland Islands', 'איי פוקלנד', <String>[
    'Atlantic/Stanley',
  ]),
  Country('501', 'BZ', 'Belize', 'בליז', <String>['America/Belize']),
  Country('502', 'GT', 'Guatemala', 'גואטמלה', <String>['America/Guatemala']),
  Country('503', 'SV', 'El Salvador', 'אל סלוודור', <String>[
    'America/El_Salvador',
  ]),
  Country('504', 'HN', 'Honduras', 'הונדורס', <String>['America/Tegucigalpa']),
  Country('505', 'NI', 'Nicaragua', 'ניקרגואה', <String>['America/Managua']),
  Country('506', 'CR', 'Costa Rica', 'קוסטה ריקה', <String>[
    'America/Costa_Rica',
  ]),
  Country('507', 'PA', 'Panama', 'פנמה', <String>['America/Panama']),
  Country('508', 'PM', 'Saint Pierre and Miquelon', 'סן פייר ומיקלון', <String>[
    'America/Miquelon',
  ]),
  Country('509', 'HT', 'Haiti', 'האיטי', <String>['America/Port-au-Prince']),
  Country('590', 'GP', 'Guadeloupe', 'גוואדלופ', <String>[
    'America/Guadeloupe',
  ]),
  Country('591', 'BO', 'Bolivia', 'בוליביה', <String>['America/La_Paz']),
  Country('592', 'GY', 'Guyana', 'גיאנה', <String>['America/Guyana']),
  Country('593', 'EC', 'Ecuador', 'אקוודור', <String>['America/Guayaquil']),
  Country('594', 'GF', 'French Guiana', 'גיאנה הצרפתית', <String>[
    'America/Cayenne',
  ]),
  Country('595', 'PY', 'Paraguay', 'פרגוואי', <String>['America/Asuncion']),
  Country('596', 'MQ', 'Martinique', 'מרטיניק', <String>['America/Martinique']),
  Country('597', 'SR', 'Suriname', 'סורינאם', <String>['America/Paramaribo']),
  Country('598', 'UY', 'Uruguay', 'אורוגוואי', <String>['America/Montevideo']),
  Country('599', 'CW', 'Curaçao', 'קוראסאו', <String>['America/Curacao']),
  Country('670', 'TL', 'Timor-Leste', 'מזרח טימור', <String>['Asia/Dili']),
  Country('673', 'BN', 'Brunei', 'ברוניי', <String>['Asia/Brunei']),
  Country('674', 'NR', 'Nauru', 'נאורו', <String>['Pacific/Nauru']),
  Country('675', 'PG', 'Papua New Guinea', 'פפואה גינאה החדשה', <String>[
    'Pacific/Port_Moresby',
  ]),
  Country('676', 'TO', 'Tonga', 'טונגה', <String>['Pacific/Tongatapu']),
  Country('677', 'SB', 'Solomon Islands', 'איי שלמה', <String>[
    'Pacific/Guadalcanal',
  ]),
  Country('678', 'VU', 'Vanuatu', 'ונואטו', <String>['Pacific/Efate']),
  Country('679', 'FJ', 'Fiji', "פיג'י", <String>['Pacific/Fiji']),
  Country('680', 'PW', 'Palau', 'פלאו', <String>['Pacific/Palau']),
  Country('682', 'CK', 'Cook Islands', 'איי קוק', <String>[
    'Pacific/Rarotonga',
  ]),
  Country('685', 'WS', 'Samoa', 'סמואה', <String>['Pacific/Apia']),
  Country('686', 'KI', 'Kiribati', 'קיריבטי', <String>['Pacific/Tarawa']),
  Country('687', 'NC', 'New Caledonia', 'קלדוניה החדשה', <String>[
    'Pacific/Noumea',
  ]),
  Country('688', 'TV', 'Tuvalu', 'טובאלו', <String>['Pacific/Funafuti']),
  Country('689', 'PF', 'French Polynesia', 'פולינזיה הצרפתית', <String>[
    'Pacific/Tahiti',
  ]),
  Country('691', 'FM', 'Micronesia', 'מיקרונזיה', <String>['Pacific/Pohnpei']),
  Country('692', 'MH', 'Marshall Islands', 'איי מרשל', <String>[
    'Pacific/Majuro',
  ]),
  Country('850', 'KP', 'North Korea', 'צפון קוריאה', <String>[
    'Asia/Pyongyang',
  ]),
  Country('852', 'HK', 'Hong Kong', 'הונג קונג', <String>['Asia/Hong_Kong']),
  Country('853', 'MO', 'Macau', 'מקאו', <String>['Asia/Macau']),
  Country('855', 'KH', 'Cambodia', 'קמבודיה', <String>['Asia/Phnom_Penh']),
  Country('856', 'LA', 'Laos', 'לאוס', <String>['Asia/Vientiane']),
  Country('880', 'BD', 'Bangladesh', 'בנגלדש', <String>['Asia/Dhaka']),
  Country('886', 'TW', 'Taiwan', 'טייוואן', <String>['Asia/Taipei']),
  Country('960', 'MV', 'Maldives', 'האיים המלדיביים', <String>[
    'Indian/Maldives',
  ]),
  Country('961', 'LB', 'Lebanon', 'לבנון', <String>['Asia/Beirut']),
  Country('962', 'JO', 'Jordan', 'ירדן', <String>['Asia/Amman']),
  Country('963', 'SY', 'Syria', 'סוריה', <String>['Asia/Damascus']),
  Country('964', 'IQ', 'Iraq', 'עיראק', <String>['Asia/Baghdad']),
  Country('965', 'KW', 'Kuwait', 'כווית', <String>['Asia/Kuwait']),
  Country('966', 'SA', 'Saudi Arabia', 'ערב הסעודית', <String>['Asia/Riyadh']),
  Country('967', 'YE', 'Yemen', 'תימן', <String>['Asia/Aden']),
  Country('968', 'OM', 'Oman', 'עומאן', <String>['Asia/Muscat']),
  Country('970', 'PS', 'Palestinian Authority', 'הרשות הפלסטינית', <String>[
    'Asia/Hebron',
  ]),
  Country('971', 'AE', 'United Arab Emirates', 'איחוד האמירויות', <String>[
    'Asia/Dubai',
  ]),
  Country('972', 'IL', 'Israel', 'ישראל', <String>['Asia/Jerusalem']),
  Country('973', 'BH', 'Bahrain', 'בחריין', <String>['Asia/Bahrain']),
  Country('974', 'QA', 'Qatar', 'קטאר', <String>['Asia/Qatar']),
  Country('975', 'BT', 'Bhutan', 'בהוטן', <String>['Asia/Thimphu']),
  Country('976', 'MN', 'Mongolia', 'מונגוליה', <String>[
    'Asia/Ulaanbaatar',
    'Asia/Hovd',
  ]),
  Country('977', 'NP', 'Nepal', 'נפאל', <String>['Asia/Kathmandu']),
  Country('992', 'TJ', 'Tajikistan', "טג'יקיסטן", <String>['Asia/Dushanbe']),
  Country('993', 'TM', 'Turkmenistan', 'טורקמניסטן', <String>['Asia/Ashgabat']),
  Country('994', 'AZ', 'Azerbaijan', "אזרבייג'ן", <String>['Asia/Baku']),
  Country('995', 'GE', 'Georgia', 'גאורגיה', <String>['Asia/Tbilisi']),
  Country('996', 'KG', 'Kyrgyzstan', 'קירגיזסטן', <String>['Asia/Bishkek']),
  Country('998', 'UZ', 'Uzbekistan', 'אוזבקיסטן', <String>['Asia/Tashkent']),
];
