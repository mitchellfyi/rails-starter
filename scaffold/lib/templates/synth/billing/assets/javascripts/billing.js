// Stripe billing integration
document.addEventListener('DOMContentLoaded', function() {
  // Initialize Stripe if publishable key is available
  if (typeof window.stripePublishableKey !== 'undefined') {
    const stripe = Stripe(window.stripePublishableKey);
    const elements = stripe.elements();

    // Create card element
    const cardElement = elements.create('card', {
      style: {
        base: {
          fontSize: '16px',
          color: '#424770',
          '::placeholder': {
            color: '#aab7c4',
          },
        },
        invalid: {
          color: '#9e2146',
        },
      },
    });

    // Mount card element if container exists
    const cardContainer = document.getElementById('card-element');
    if (cardContainer) {
      cardElement.mount('#card-element');
    }

    // Handle real-time validation errors from the card Element
    cardElement.on('change', function(event) {
      const displayError = document.getElementById('card-errors');
      if (event.error) {
        displayError.textContent = event.error.message;
        displayError.classList.remove('hidden');
      } else {
        displayError.textContent = '';
        displayError.classList.add('hidden');
      }
    });

    // Handle form submission
    const form = document.getElementById('payment-form');
    if (form) {
      form.addEventListener('submit', async function(event) {
        event.preventDefault();

        const submitButton = form.querySelector('button[type="submit"]');
        const originalText = submitButton.textContent;
        
        // Disable submit button and show loading state
        submitButton.disabled = true;
        submitButton.textContent = 'Processing...';

        try {
          // Create payment method
          const {error, paymentMethod} = await stripe.createPaymentMethod({
            type: 'card',
            card: cardElement,
            billing_details: {
              email: form.querySelector('input[name="email"]')?.value,
              name: form.querySelector('input[name="name"]')?.value,
            },
          });

          if (error) {
            // Show error to customer
            showError(error.message);
          } else {
            // Add payment method ID to form and submit
            const hiddenInput = document.createElement('input');
            hiddenInput.type = 'hidden';
            hiddenInput.name = 'payment_method';
            hiddenInput.value = paymentMethod.id;
            form.appendChild(hiddenInput);
            
            // Submit the form
            form.submit();
          }
        } catch (err) {
          showError('An unexpected error occurred.');
        } finally {
          // Re-enable submit button
          submitButton.disabled = false;
          submitButton.textContent = originalText;
        }
      });
    }

    // Handle subscription updates that require 3D Secure
    const confirmButton = document.getElementById('confirm-payment');
    if (confirmButton) {
      confirmButton.addEventListener('click', async function() {
        const clientSecret = this.dataset.clientSecret;
        
        const {error} = await stripe.confirmCardPayment(clientSecret, {
          payment_method: {
            card: cardElement,
          }
        });

        if (error) {
          showError(error.message);
        } else {
          // Payment succeeded, redirect to success page
          window.location.href = '/billing?payment=success';
        }
      });
    }

    function showError(message) {
      const errorElement = document.getElementById('card-errors');
      errorElement.textContent = message;
      errorElement.classList.remove('hidden');
      
      // Auto-hide error after 5 seconds
      setTimeout(() => {
        errorElement.classList.add('hidden');
      }, 5000);
    }
  }

  // Handle plan selection and coupon application
  const couponForm = document.getElementById('coupon-form');
  if (couponForm) {
    couponForm.addEventListener('submit', function(e) {
      e.preventDefault();
      
      const couponCode = couponForm.querySelector('input[name="coupon_code"]').value;
      const currentUrl = new URL(window.location);
      currentUrl.searchParams.set('coupon_code', couponCode);
      window.location.href = currentUrl.toString();
    });
  }

  // Handle subscription cancellation confirmation
  const cancelLinks = document.querySelectorAll('a[data-confirm]');
  cancelLinks.forEach(link => {
    link.addEventListener('click', function(e) {
      if (!confirm(this.dataset.confirm)) {
        e.preventDefault();
      }
    });
  });

  // Auto-refresh billing status (useful for webhook delays)
  if (window.location.pathname === '/billing' && window.location.search.includes('refresh=true')) {
    setTimeout(() => {
      window.location.href = '/billing';
    }, 3000);
  }
});

// Utility function to format currency
function formatCurrency(amount, currency = 'USD') {
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: currency,
  }).format(amount / 100);
}

// Export for use in other scripts
window.BillingUtils = {
  formatCurrency: formatCurrency
};