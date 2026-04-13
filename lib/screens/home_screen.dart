import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

// TEMPORARY FILE — will be deleted at end of project
// This is just a placeholder so the app doesn't crash
// Real screen is: lib/features/auth/screens/role_selection_screen.dart

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.check_circle,
              color: AppColors.successGreen,
              size: 80,
            ),
            const SizedBox(height: 24),
            const Text(
              'Navigation Works!',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Splash → Here ✅',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 48),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacementNamed(
                    context,
                    '/',
                  );
                },
                child: const Text('Back to Splash'),
              ),
            ),
          ],
        ),
      ),
    );
}





// //screen before half screen blue splash
// import 'package:flutter/material.dart';
// import '../models/medicine.dart';
// import 'add_medicine_screen.dart';

// class HomeScreen extends StatefulWidget {
//   const HomeScreen({super.key});

//   @override
//   State<HomeScreen> createState() => _HomeScreenState();
// }

// class _HomeScreenState extends State<HomeScreen> {
//   List<Medicine> medicines = [
//     Medicine(
//       id: '1',
//       name: 'Aspirin',
//       dosage: '500mg',
//       remindTimes: ['08:00', '20:00'],
//       notes: 'Take with food',
//     ),
//     Medicine(
//       id: '2',
//       name: 'Vitamin D',
//       dosage: '1000 IU',
//       remindTimes: ['09:00'],
//       notes: '',
//     ),
//   ];

//   void _addMedicine(Medicine medicine) {
//     setState(() {
//       medicines.add(medicine);
//     });
//   }

//   void _removeMedicine(String id) {
//     setState(() {
//       medicines.removeWhere((med) => med.id == id);
//     });
//   }

//   void _toggleMedicineTaken(String id) {
//     setState(() {
//       final medicine = medicines.firstWhere((med) => med.id == id);
//       medicine.isTaken = !medicine.isTaken;
//     });
//   }

//   @override
//   Widget build(BuildContext context) => Scaffold(
//       appBar: AppBar(
//         title: const Text('Medicine Reminder'),
//         elevation: 0,
//       ),
//       body: medicines.isEmpty
//           ? Center(
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   Icon(
//                     Icons.medication,
//                     size: 80,
//                     color: Colors.blue.shade300,
//                   ),
//                   const SizedBox(height: 20),
//                   Text(
//                     'No medicines added yet',
//                     style: Theme.of(context).textTheme.titleLarge,
//                   ),
//                   const SizedBox(height: 10),
//                   const Text('Add your first medicine to get started'),
//                 ],
//               ),
//             )
//           : ListView.builder(
//               padding: const EdgeInsets.all(16),
//               itemCount: medicines.length,
//               itemBuilder: (context, index) {
//                 final medicine = medicines[index];
//                 return Card(
//                   margin: const EdgeInsets.only(bottom: 12),
//                   child: Padding(
//                     padding: const EdgeInsets.all(16),
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Row(
//                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                           children: [
//                             Expanded(
//                               child: Column(
//                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                 children: [
//                                   Text(
//                                     medicine.name,
//                                     style: Theme.of(context)
//                                         .textTheme
//                                         .titleMedium
//                                         ?.copyWith(
//                                           fontWeight: FontWeight.bold,
//                                         ),
//                                   ),
//                                   const SizedBox(height: 4),
//                                   Text(
//                                     medicine.dosage,
//                                     style: Theme.of(context)
//                                         .textTheme
//                                         .bodySmall
//                                         ?.copyWith(
//                                           color: Colors.grey[600],
//                                         ),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                             IconButton(
//                               icon: const Icon(Icons.delete, color: Colors.red),
//                               onPressed: () => _removeMedicine(medicine.id),
//                             ),
//                           ],
//                         ),
//                         const SizedBox(height: 12),
//                         Text(
//                           'Reminder Times:',
//                           style: Theme.of(context).textTheme.bodySmall,
//                         ),
//                         const SizedBox(height: 8),
//                         Wrap(
//                           spacing: 8,
//                           children: medicine.remindTimes
//                               .map(
//                                 (time) => Chip(
//                                   label: Text(time),
//                                   backgroundColor: Colors.blue.shade100,
//                                 ),
//                               )
//                               .toList(),
//                         ),
//                         if (medicine.notes.isNotEmpty) ...[
//                           const SizedBox(height: 12),
//                           Text(
//                             'Notes: ${medicine.notes}',
//                             style: Theme.of(context)
//                                 .textTheme
//                                 .bodySmall
//                                 ?.copyWith(
//                                   fontStyle: FontStyle.italic,
//                                 ),
//                           ),
//                         ],
//                         const SizedBox(height: 12),
//                         ElevatedButton(
//                           onPressed: () => _toggleMedicineTaken(medicine.id),
//                           style: ElevatedButton.styleFrom(
//                             backgroundColor: medicine.isTaken
//                                 ? Colors.green
//                                 : Colors.grey.shade300,
//                           ),
//                           child: Text(
//                             medicine.isTaken ? '✓ Taken' : 'Mark as Taken',
//                             style: TextStyle(
//                               color:
//                                   medicine.isTaken ? Colors.white : Colors.black,
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 );
//               },
//             ),
//       floatingActionButton: FloatingActionButton(
//         onPressed: () {
//           Navigator.push(
//             context,
//             MaterialPageRoute(
//               builder: (context) => AddMedicineScreen(
//                 onMedicineAdded: _addMedicine,
//               ),
//             ),
//           );
//         },
//         child: const Icon(Icons.add),
//       ),
//     );
// }
