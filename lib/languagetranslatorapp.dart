import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final stt.SpeechToText speech = stt.SpeechToText();
  final TextEditingController _inputController = TextEditingController();
  final TextEditingController _outputController = TextEditingController();
  final FlutterTts flutterTts = FlutterTts();
  List<dynamic> data = [];
  String _selectedSourceLanguage = '';
  String _selectedTargetLanguage = '';
  String _outputText = '';
  String _sourceLanguage = '';
  List<String> translationHistory = [];

  @override
  void initState() {
    super.initState();
    _fetchSupportedLanguages();
    _loadTranslationHistory();
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
            'from': _selectedSourceLanguage,
            'to': _selectedTargetLanguage,
            'text': _inputController.text,
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
          'from': _selectedSourceLanguage,
          'to': _selectedTargetLanguage,
          'text': _inputController.text,
        },
      );

      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (data.containsKey('trans')) {
          final String translatedText = data['trans'];
          setState(() {
            _outputText = translatedText;
            _outputController.text = translatedText;
          });

          // Save the translation to history
          _addToTranslationHistory(
              '${_inputController.text} -> $translatedText');
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

  Future<void> _addToTranslationHistory(String translation) async {
    translationHistory.add(
        '${_selectedSourceLanguage}${_selectedTargetLanguage}$translation');
    await _saveTranslationHistory();
  }

  Future<void> _saveTranslationHistory() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setStringList('translationHistory', translationHistory);
  }

  Future<void> _loadTranslationHistory() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? loadedHistory = prefs.getStringList('translationHistory');
    if (loadedHistory != null) {
      setState(() {
        translationHistory = loadedHistory;
      });
    }
  }

  Future<void> _clearTranslationHistory() async {
    setState(() {
      translationHistory = [];
    });
    await _saveTranslationHistory();
  }

  Future<String> _detectLanguage(String text) async {
    final response = await http.post(
      Uri.parse(
        'https://google-translate113.p.rapidapi.com/api/v1/translator/detect-language',
      ),
      headers: {
        'content-type': 'application/x-www-form-urlencoded',
        'X-RapidAPI-Key': 'f33b805ccdmshec4c67929283b7cp1ac331jsn92a7ae8d08d1',
        'X-RapidAPI-Host': 'google-translate113.p.rapidapi.com'
      },
      body: {
        'q': text,
      },
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);

      if (data.containsKey('language')) {
        final String detectedLanguage = data['language'];
        return detectedLanguage;
      } else {
        print('Missing "language" field in the response');
      }
    } else {
      print('Failed to detect language. Status code: ${response.statusCode}');
    }

    return '';
  }

  Future<void> _autoDetectLanguage() async {
    if (_inputController.text.isEmpty) {
      final detectedLanguage = await _detectLanguage(_inputController.text);

      if (detectedLanguage.isNotEmpty) {
        setState(() {
          _sourceLanguage = detectedLanguage;
          _selectedSourceLanguage = detectedLanguage;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Language Translator'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Column(
                    children: [
                      TextField(
                        controller: _inputController,
                        decoration: InputDecoration(
                          labelText: 'Enter Text',
                          suffixIcon: IconButton(
                            icon: Icon(Icons.volume_up),
                            onPressed: () => _speakText(_inputController.text),
                          ),
                          suffix: _sourceLanguage.isNotEmpty
                              ? Text('Language: $_sourceLanguage')
                              : null,
                        ),
                        onChanged: (text) {
                          _autoDetectLanguage();
                        },
                      ),
                      SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('$_sourceLanguage'),
                          Flexible(
                            child: DropdownButton<String>(
                              value: _selectedSourceLanguage,
                              onChanged: (String? newValue) {
                                print('$newValue');
                                setState(() {
                                  _selectedSourceLanguage = newValue!;
                                });
                              },
                              items: data.map<DropdownMenuItem<String>>(
                                  (dynamic value) {
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
                  padding: const EdgeInsets.all(10.0),
                  child: Column(
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
                          Text('$_selectedTargetLanguage'),
                          Flexible(
                            child: DropdownButton<String>(
                              value: _selectedTargetLanguage,
                              onChanged: (String? newValue) {
                                setState(() {
                                  _selectedTargetLanguage = newValue!;
                                });
                              },
                              items: data.map<DropdownMenuItem<String>>(
                                  (dynamic value) {
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
              SizedBox(height: 16),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => HistoryScreen(
                translationHistory: translationHistory,
                data: data,
                onClearHistory: _clearTranslationHistory,
              ),
            ),
          );
        },
        tooltip: 'History',
        child: Icon(Icons.history),
      ),
    );
  }

  Future<void> _speakText(String text) async {
    print('Speaking text: $text');
    await flutterTts.speak(text);
  }

  void _startListening(TextEditingController inputController) async {
    bool available = await speech.initialize(
      onStatus: (status) {
        print('Speech to text status: $status');
      },
      onError: (errorNotification) {
        print('Speech to text error: $errorNotification');
      },
    );

    if (available) {
      // Start listening
      speech.listen(
        onResult: (result) {
          if (result.finalResult) {
            // Update the input text field with the recognized speech
            setState(() {
              inputController.text = result.recognizedWords;
            });
          }
        },
      );
    } else {
      print('Speech to text not available');
    }
  }
}

class HistoryScreen extends StatefulWidget {
  final List<String> translationHistory;
  final List<dynamic> data;
  final Future<void> Function() onClearHistory;

  HistoryScreen({
    required this.translationHistory,
    required this.data,
    required this.onClearHistory,
  });

  @override
  _HistoryScreenState createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  Future<void> _confirmDelete() async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirm Delete'),
          content: Text('Are you sure you want to delete the entire history?'),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Delete'),
              onPressed: () async {
                Navigator.of(context).pop(); // Close the dialog
                await _deleteHistory(); // Call the method to delete history
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteHistory() async {
    try {
      setState(() {
        _deleting = true; // Show loader
      });

      // Simulate asynchronous operation (replace with actual logic)
      await widget.onClearHistory();

      // Navigate back to trigger page reload
      Navigator.of(context).pop();

      // Simulate screen refresh (replace with actual logic)
      await Future.delayed(Duration(seconds: 2));

      // Navigate back to the history page
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => HistoryScreen(
            translationHistory: widget.translationHistory,
            data: widget.data,
            onClearHistory: widget.onClearHistory,
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _deleting = false; // Hide loader in case of an error
      });
      print('Error clearing history: $e');
    }
  }

  String getLanguageName(String languageCode) {
    var language = widget.data.firstWhere(
      (element) => element['code'] == languageCode,
      orElse: () => {'language': 'Unknown'},
    );
    return language['language'].toString();
  }

  bool _deleting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('History'),
        actions: [
          IconButton(
            icon: Icon(Icons.delete),
            onPressed: () async {
              await _confirmDelete();
            },
          ),
        ],
      ),
      body: _deleting
          ? Center(
              child: CircularProgressIndicator(),
            )
          : widget.translationHistory.isEmpty
              ? Center(
                  child: Text('No translation history'),
                )
              : ListView.builder(
                  itemCount: widget.translationHistory.length,
                  itemBuilder: (context, index) {
                    String translationText = widget.translationHistory[index];

                    // Extracting information from the concatenated string
                    String sourceLanguageCode = translationText[0];
                    String targetLanguageCode = translationText[0];
                    String translatedText = translationText.substring(0);

                    // Get language names from the language codes
                    String sourceLanguageName =
                        getLanguageName(sourceLanguageCode);
                    String targetLanguageName =
                        getLanguageName(targetLanguageCode);

                    // Unique key for each translation card
                    Key cardKey = Key(widget.translationHistory[index]);

                    return Dismissible(
                      key: cardKey,
                      direction: DismissDirection.startToEnd,
                      onDismissed: (direction) async {
                        // Show confirmation dialog
                        bool confirmDelete = await _confirmDeleteDialog();

                        if (confirmDelete) {
                          // Perform deletion logic here if needed
                          // Remove the dismissed translation from the list
                          setState(() {
                            widget.translationHistory.removeAt(index);
                          });

                          // Show a snackbar indicating the translation was deleted
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Translation deleted'),
                            ),
                          );
                        } else {
                          // If canceled, refresh the page
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (context) => HistoryScreen(
                                translationHistory: widget.translationHistory,
                                data: widget.data,
                                onClearHistory: widget.onClearHistory,
                              ),
                            ),
                          );
                        }
                      },
                      background: Container(
                        color: Colors.red,
                        padding: EdgeInsets.all(16.0),
                        alignment: Alignment.centerLeft,
                        child: Icon(
                          Icons.delete,
                          color: Colors.white,
                        ),
                      ),
                      child: Card(
                        elevation: 3,
                        margin: EdgeInsets.all(8.0),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('From: $sourceLanguageName'),
                              Text('To: $targetLanguageName'),
                              Text('Translation: $translatedText'),
                              // Add more information as needed
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Future<bool> _confirmDeleteDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Confirm Delete'),
              content:
                  Text('Are you sure you want to delete this translation?'),
              actions: <Widget>[
                TextButton(
                  child: Text('Cancel'),
                  onPressed: () {
                    Navigator.of(context).pop(false); // Close the dialog
                  },
                ),
                TextButton(
                  child: Text('Delete'),
                  onPressed: () {
                    Navigator.of(context).pop(true); // Close the dialog
                  },
                ),
              ],
            );
          },
        ) ??
        false; // Default to false if the dialog is dismissed
  }
}
