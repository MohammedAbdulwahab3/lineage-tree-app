import 'dart:convert';
import 'package:family_tree/data/models/post.dart';
import 'package:family_tree/data/models/message.dart';
import 'package:family_tree/data/models/appointment.dart';
import 'package:family_tree/data/models/comment.dart';
import 'package:family_tree/data/services/api_service.dart';

/// Repository for family group operations (posts, chat, events)
/// Uses Go backend API instead of Firestore
class GroupRepository {
  final ApiService _api = ApiService();

  // ===== POSTS =====

  /// Watch all posts (polling-based since REST doesn't support real-time)
  Stream<List<Post>> watchPosts(String familyTreeId) async* {
    while (true) {
      try {
        final posts = await getPosts();
        yield posts;
      } catch (e) {
        print('Error fetching posts: $e');
        yield [];
      }
      await Future.delayed(const Duration(seconds: 3));
    }
  }

  /// Get all posts
  Future<List<Post>> getPosts() async {
    try {
      final response = await _api.get('/api/posts');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Post.fromJson(json as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      print('Error getting posts: $e');
      return [];
    }
  }

  /// Add a new post
  Future<String> addPost(Post post) async {
    try {
      final response = await _api.post('/api/posts', body: post.toJson());
      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['id'] ?? '';
      }
      print('Create post failed with status ${response.statusCode}: ${response.body}');
      throw Exception('Failed to create post (${response.statusCode})');
    } catch (e) {
      print('Error adding post: $e');
      rethrow;
    }
  }

  /// Delete a post
  Future<void> deletePost(String postId) async {
    try {
      await _api.delete('/api/posts/$postId');
    } catch (e) {
      print('Error deleting post: $e');
      rethrow;
    }
  }

  // ===== MESSAGES =====

  /// Watch all messages (polling-based)
  Stream<List<Message>> watchMessages(String familyTreeId) async* {
    while (true) {
      try {
        final messages = await getMessages();
        yield messages;
      } catch (e) {
        print('Error fetching messages: $e');
        yield [];
      }
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  /// Get all messages
  Future<List<Message>> getMessages() async {
    try {
      final response = await _api.get('/api/messages');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Message.fromJson(json as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      print('Error getting messages: $e');
      return [];
    }
  }

  /// Send a message
  Future<String> sendMessage(Message message) async {
    try {
      final response = await _api.post('/api/messages', body: message.toJson());
      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['id'] ?? '';
      }
      print('Send message failed with status ${response.statusCode}: ${response.body}');
      throw Exception('Failed to send message (${response.statusCode})');
    } catch (e) {
      print('Error sending message: $e');
      rethrow;
    }
  }

  // ===== EVENTS =====

  /// Watch all events (polling-based)
  Stream<List<Appointment>> watchAppointments(String familyTreeId) async* {
    while (true) {
      try {
        final events = await getEvents();
        yield events;
      } catch (e) {
        print('Error fetching events: $e');
        yield [];
      }
      await Future.delayed(const Duration(seconds: 3));
    }
  }

  /// Get all events
  Future<List<Appointment>> getEvents() async {
    try {
      final response = await _api.get('/api/events');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Appointment.fromJson(json as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      print('Error getting events: $e');
      return [];
    }
  }

  /// Add a new event
  Future<String> addAppointment(Appointment appointment) async {
    try {
      final response = await _api.post('/api/events', body: appointment.toJson());
      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['id'] ?? '';
      }
      print('Create event failed with status ${response.statusCode}: ${response.body}');
      throw Exception('Failed to create event (${response.statusCode})');
    } catch (e) {
      print('Error adding event: $e');
      rethrow;
    }
  }

  /// Delete an event
  Future<void> deleteAppointment(String appointmentId) async {
    try {
      await _api.delete('/api/events/$appointmentId');
    } catch (e) {
      print('Error deleting event: $e');
      rethrow;
    }
  }

  /// Toggle RSVP for an event
  Future<void> toggleRSVP(String eventId, String userId) async {
    try {
      await _api.post('/api/events/$eventId/rsvp');
    } catch (e) {
      print('Error toggling RSVP: $e');
      rethrow;
    }
  }

  // ===== COMMENTS =====

  /// Watch comments for a post (polling-based)
  Stream<List<Comment>> watchComments(String postId) async* {
    while (true) {
      try {
        final comments = await getComments(postId);
        yield comments;
      } catch (e) {
        print('Error fetching comments: $e');
        yield [];
      }
      await Future.delayed(const Duration(seconds: 3));
    }
  }

  /// Get comments for a post
  Future<List<Comment>> getComments(String postId) async {
    try {
      final response = await _api.get('/api/posts/$postId/comments');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Comment.fromJson(json as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      print('Error getting comments: $e');
      return [];
    }
  }

  /// Add a comment to a post
  Future<String> addComment(Comment comment) async {
    try {
      final response = await _api.post(
        '/api/posts/${comment.postId}/comments',
        body: comment.toJson(),
      );
      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return data['id'] ?? '';
      }
      throw Exception('Failed to add comment');
    } catch (e) {
      print('Error adding comment: $e');
      rethrow;
    }
  }

  /// Delete a comment
  Future<void> deleteComment(String commentId) async {
    try {
      await _api.delete('/api/comments/$commentId');
    } catch (e) {
      print('Error deleting comment: $e');
      rethrow;
    }
  }

  // ===== REACTIONS =====

  /// Toggle reaction on a post
  Future<void> toggleReaction(String postId, String userId, String emoji) async {
    try {
      await _api.post(
        '/api/posts/$postId/reactions',
        body: {'emoji': emoji, 'userId': userId},
      );
    } catch (e) {
      print('Error toggling reaction: $e');
      rethrow;
    }
  }
}
