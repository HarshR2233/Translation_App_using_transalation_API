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

  Future<void> _translateText() async {
    if (_inputController.text.isEmpty || _selectedTargetLanguage.isEmpty) {
      print('Input text or target language is empty');
      return;
    }

    try {
      print('Request body: ${json.encode({
            'from':
                _selectedSourceLanguage, // Remove or set to an empty string for auto-detection
            'to': _selectedTargetLanguage,
            'text': _inputController.text, // Use input text as source text
          })}');

      final response = await http.post(
        Uri.parse(
          'https://google-translate113.p.rapidapi.com/api/v1/translator/text',
        ),
        headers: {
          'content-type': 'application/x-www-form-urlencoded',
          'X-RapidAPI-Key':
              'f33b805ccdmshec4c67929283b7cp1ac331jsn92a7ae8d08d1',
          'X-RapidAPI-Host': 'google-translate113.p.rapidapi.com',
        },
        body: {
          'from':
              _selectedSourceLanguage, // Remove or set to an empty string for auto-detection
          'to': _selectedTargetLanguage,
          'text': _inputController.text, // Use input text as source text
        },
      );

      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (data.containsKey('trans')) {
          final String translatedText = data['trans'];
          setState(() {
            _outputText = translatedText;
            _outputController.text =
                translatedText; // Set translated text to the output field
          });
        } else {
          print('Missing "trans" field in the response');
        }
      } else {
        print(
            'Failed to load translation. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error during translation request: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Language Translator'),
      ),
      body: SingleChildScrollView(
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
                          icon: Icon(Icons.volume_up),
                          onPressed: () => _speakText(_inputController.text),
                        ),
                      ),
                    ),
                    SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Source Language: $_sourceLanguage'),
                        Flexible(
                          child: DropdownButton<String>(
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
                        labelText: 'Translated Text',
                        suffixIcon: IconButton(
                          icon: Icon(Icons.volume_up),
                          onPressed: () => _speakText(_outputController.text),
                        ),
                      ),
                    ),
                    SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Target Language: $_selectedTargetLanguage'),
                        Flexible(
                          child: DropdownButton<String>(
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
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                await _translateText();
              },
              child: Text('Translate'),
            ),
            // SizedBox(height: 16),
            // Row(
            //   mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            //   children: [
            //     ElevatedButton(
            //       onPressed: () => _speakText(_inputController.text),
            //       child: Icon(Icons.volume_up),
            //     ),
            //     ElevatedButton(
            //       onPressed: () {
            //         if (_outputController.text.isNotEmpty) {
            //           _speakText(_outputController.text);
            //         }
            //       },
            //       child: Icon(Icons.volume_up),
            //     ),
            //   ],
            // ),
          ],
        ),
      ),
    );
  }

  Future<void> _speakText(String text) async {
    print('Speaking text: $text');
    await flutterTts.speak(text);
  }

  void _startListening(TextEditingController inputController) {
    // Implement speech-to-text logic
  }
}

void main() {
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: LanguageTranslatorApp(),
  ));
}
