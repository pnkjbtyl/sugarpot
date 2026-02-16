import 'package:flutter/material.dart';
import '../main.dart';

class LocationSelectionDialog extends StatelessWidget {
  final List<dynamic> locations;
  final String otherUserName;

  const LocationSelectionDialog({
    super.key,
    required this.locations,
    required this.otherUserName,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxHeight: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Select a location to meet $otherUserName',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            if (locations.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('No locations found within 20km'),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: locations.length,
                  itemBuilder: (context, index) {
                    final location = locations[index];
                    return ListTile(
                      leading: Icon(Icons.location_on, color: primaryColor),
                      title: Text(location['name'] ?? 'Unknown'),
                      subtitle: location['description'] != null
                          ? Text(location['description'])
                          : null,
                      onTap: () {
                        Navigator.of(context).pop(location);
                      },
                    );
                  },
                ),
              ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}
