const { db } = require('../config/database');

exports.markRead = (req, res) => {
  try {
    const { userId, id } = req.params;
    db.prepare('UPDATE notifications SET read = 1 WHERE id = ? AND user_id = ?').run(id, userId);
    return res.json({ success: true, message: 'Notification marked as read' });
  } catch (error) {
    console.error('Mark read error:', error);
    return res.status(500).json({ success: false, error: 'Failed to mark notification read' });
  }
};

exports.markAllRead = (req, res) => {
  try {
    const { userId } = req.params;
    db.prepare('UPDATE notifications SET read = 1 WHERE user_id = ?').run(userId);
    return res.json({ success: true, message: 'All notifications marked as read' });
  } catch (error) {
    console.error('Mark all read error:', error);
    return res.status(500).json({ success: false, error: 'Failed to mark all notifications read' });
  }
};
