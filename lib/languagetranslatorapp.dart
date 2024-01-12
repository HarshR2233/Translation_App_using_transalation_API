import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class LanguageTranslatorApp extends StatefulWidget {
  @override
  _LanguageTranslatorAppState createState() => _LanguageTranslatorAppState();
}

class _LanguageTranslatorAppState extends State<LanguageTranslatorApp> {
  final TextEditingController _inputController = TextEditingController();
  final TextEditingController _outputController = TextEditingController();
  final FlutterTts flutterTts = FlutterTts();
  final stt.SpeechToText speech = stt.SpeechToText();
  List<dynamic> data = [];
  String _selectedSourceLanguage = '';
  String _selectedTargetLanguage = '';
  String _outputText = '';
  String _sourceLanguage = '';

  @override
  void initState() {
    super.initState();
    _fetchSupportedLanguages();
  }

  Future<void> _fetchSupportedLanguages() async {
    final response = await http.get(
      Uri.parse(
        'https://google-translate113.p.rapidapi.com/api/v1/translator/support-languages',
      ),
      headers: {
        'X-RapidAPI-Key': 'f33b805ccdmshec4c67929283b7cp1ac331jsn92a7ae8d08d1',
        'X-RapidAPI-Host': 'google-translate113.p.rapidapi.com',
      },
    );

    if (response.statusCode == 200) {
      setState(() {
        data = json.decode(response.body);
        // Set initial values if needed
        _selectedSourceLanguage =
            data.isNotEmpty ? data[0]['code'].toString() : '';
        _selectedTargetLanguage =
            data.isNotEmpty ? data[0]['code'].toString() : '';
      });
    } else {
      print(
          'Failed to fetch supported languages. Status code: ${response.statusCode}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Language Translator'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _inputController,
                      decoration: InputDecoration(
                        labelText: 'Enter Text',
                        suffixIcon: IconButton(
                          icon: Icon(Icons.mic),
                          onPressed: () => _startListening(_inputController),
                        ),
                      ),
                    ),
                    SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Source Language: $_sourceLanguage'),
                        DropdownButton<String>(
                          value: _selectedSourceLanguage,
                          onChanged: (String? newValue) {
                            print('Source Language Changed: $newValue');
                            setState(() {
                              _selectedSourceLanguage = newValue!;
                            });
                          },
                          items: data
                              .map<DropdownMenuItem<String>>((dynamic value) {
                            return DropdownMenuItem<String>(
                              value: value['code'].toString(),
                              child: Text(value['language'].toString()),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _outputController,
                      decoration: InputDecoration(
                        labelText: 'Translated Text (Editable)',
                        suffixIcon: IconButton(
                          icon: Icon(Icons.mic),
                          onPressed: () => _startListening(_outputController),
                        ),
                      ),
                    ),
                    SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Target Language: $_selectedTargetLanguage'),
                        DropdownButton<String>(
                          value: _selectedTargetLanguage,
                          onChanged: (String? newValue) {
                            print('Target Language Changed: $newValue');
                            setState(() {
                              _selectedTargetLanguage = newValue!;
                            });
                          },
                          items: data
                              .map<DropdownMenuItem<String>>((dynamic value) {
                            return DropdownMenuItem<String>(
                              value: value['code'].toString(),
                              child: Text(value['language'].toString()),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _translateText(),
              child: Text('Translate'),
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () => _speakText(_inputController.text),
                  child: Icon(Icons.volume_up),
                ),
                ElevatedButton(
                  onPressed: () => _speakText(_outputController.text),
                  child: Icon(Icons.volume_up),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _translateText() async {
    if (_selectedTargetLanguage.isEmpty) {
      print('Please select a target language.');
      return;
    }

    try {
      final response = await http.post(
        Uri.parse(
          'https://google-translate113.p.rapidapi.com/api/v1/translator/json',
        ),
        headers: {
          'content-type': 'application/x-www-form-urlencoded',
          'X-RapidAPI-Key':
              'f33b805ccdmshec4c67929283b7cp1ac331jsn92a7ae8d08d1',
          'X-RapidAPI-Host': 'google-translate113.p.rapidapi.com',
        },
        body: {
          'q': _inputController.text,
          'source': _selectedSourceLanguage,
          'target': _selectedTargetLanguage,
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (data.containsKey('data') && data['data'] is Map<String, dynamic>) {
          final Map<String, dynamic> translationData = data['data'];

          if (translationData.containsKey('translations') &&
              translationData['translations'] is List) {
            final List<dynamic> translations = translationData['translations'];

            if (translations.isNotEmpty) {
              final Map<String, dynamic> translation = translations[0];

              if (translation.containsKey('trans') &&
                  translation.containsKey('source_language') &&
                  translation.containsKey('source_language_code')) {
                final String translatedText = translation['trans'];
                final String sourceLanguage = translation['source_language'];
                final String sourceLanguageCode =
                    translation['source_language_code'];

                setState(() {
                  _outputText = translatedText;
                  _sourceLanguage = '$sourceLanguage ($sourceLanguageCode)';
                });
              } else {
                print(
                    'Invalid translation structure in the response: $translation');
              }
            } else {
              print('No translations available in the response.');
            }
          } else {
            print(
                'Invalid "translations" field in the response: ${translationData['translations']}');
          }
        } else {
          print('Invalid "data" field in the response: ${data['data']}');
        }
      } else {
        print(
            'Failed to load translation. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error during translation: $e');
    }
  }

  Future<void> _speakText(String text) async {
    await flutterTts.speak(text);
  }

  void _startListening(TextEditingController inputController) {
    // Implement speech-to-text logic
  }
}

void main() {
  runApp(MaterialApp(
    home: LanguageTranslatorApp(),
  ));
}
