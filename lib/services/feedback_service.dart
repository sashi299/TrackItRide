import 'supabase_service.dart';

class FeedbackService {
  Future<void> submitFeedback(String userId, String feedbackText, String userType) async {
    await SupabaseService.submitFeedback(
      feedback: feedbackText,
      email: userId,
    );
  }

  Future<List<Map<String, dynamic>>> getFeedbackList() async {
    return await SupabaseService.getFeedbacks();
  }
}
