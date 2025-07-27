import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="notifications"
export default class extends Controller {
  static values = { userId: String }
  static targets = ["feed", "count"]

  connect() {
    // Subscribe to notifications channel for real-time updates
    this.subscription = this.createSubscription()
  }

  disconnect() {
    if (this.subscription) {
      this.subscription.unsubscribe()
    }
  }

  createSubscription() {
    // This would connect to your ActionCable/Turbo Stream channel
    // Implementation depends on your specific setup
    return {
      unsubscribe: () => {} // Placeholder
    }
  }

  markAsRead(event) {
    const notificationId = event.target.dataset.notificationId
    
    fetch(`/notifications/${notificationId}/read`, {
      method: 'PATCH',
      headers: {
        'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content,
        'Content-Type': 'application/json'
      }
    })
    .then(response => response.json())
    .then(data => {
      // Update UI to show notification as read
      const notificationElement = document.querySelector(`#notification_${notificationId}`)
      if (notificationElement) {
        notificationElement.classList.remove('unread')
        notificationElement.classList.add('read')
      }
      
      // Update notification count
      this.updateNotificationCount()
    })
    .catch(error => {
      console.error('Error marking notification as read:', error)
    })
  }

  dismiss(event) {
    const notificationId = event.target.dataset.notificationId
    
    if (!confirm('Are you sure you want to dismiss this notification?')) {
      return
    }
    
    fetch(`/notifications/${notificationId}/dismiss`, {
      method: 'PATCH',
      headers: {
        'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content,
        'Content-Type': 'application/json'
      }
    })
    .then(response => {
      if (response.ok) {
        // Remove notification from UI
        const notificationElement = document.querySelector(`#notification_${notificationId}`)
        if (notificationElement) {
          notificationElement.remove()
        }
        
        // Update notification count
        this.updateNotificationCount()
      }
    })
    .catch(error => {
      console.error('Error dismissing notification:', error)
    })
  }

  markAllRead() {
    fetch('/notifications/mark_all_read', {
      method: 'PATCH',
      headers: {
        'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content,
        'Content-Type': 'application/json'
      }
    })
    .then(response => {
      if (response.ok) {
        // Mark all notifications as read in UI
        document.querySelectorAll('.notification-item.unread').forEach(element => {
          element.classList.remove('unread')
          element.classList.add('read')
        })
        
        // Update notification count
        this.updateNotificationCount()
      }
    })
    .catch(error => {
      console.error('Error marking all notifications as read:', error)
    })
  }

  dismissAll() {
    if (!confirm('Are you sure you want to dismiss all notifications?')) {
      return
    }
    
    fetch('/notifications/dismiss_all', {
      method: 'DELETE',
      headers: {
        'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content,
        'Content-Type': 'application/json'
      }
    })
    .then(response => {
      if (response.ok) {
        // Remove all notifications from UI
        if (this.hasFeedTarget) {
          this.feedTarget.innerHTML = `
            <div class="p-8 text-center text-gray-500">
              <h3 class="text-lg font-medium mb-2">No notifications</h3>
              <p>You're all caught up! New notifications will appear here.</p>
            </div>
          `
        }
        
        // Update notification count
        this.updateNotificationCount()
      }
    })
    .catch(error => {
      console.error('Error dismissing all notifications:', error)
    })
  }

  updateNotificationCount() {
    // Count unread notifications in current view
    const unreadCount = document.querySelectorAll('.notification-item.unread').length
    
    // Update any notification count elements
    document.querySelectorAll('[data-notification-count]').forEach(element => {
      element.textContent = unreadCount
      element.style.display = unreadCount > 0 ? 'inline-flex' : 'none'
    })
  }
}