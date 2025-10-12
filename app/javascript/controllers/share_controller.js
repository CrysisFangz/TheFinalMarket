// Share Controller
// Handles product sharing via native share API or fallback
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  open(event) {
    event.preventDefault()
    
    const shareData = {
      title: document.title,
      text: document.querySelector('meta[name="description"]')?.content || '',
      url: window.location.href
    }

    // Check if native share is available
    if (navigator.share) {
      navigator.share(shareData)
        .then(() => console.log('Shared successfully'))
        .catch((error) => console.log('Error sharing:', error))
    } else {
      // Fallback: show custom share modal
      this.showShareModal(shareData)
    }
  }

  showShareModal(data) {
    const modal = document.createElement('div')
    modal.className = 'fixed inset-0 z-50 flex items-center justify-center p-4 bg-black bg-opacity-50'
    modal.innerHTML = `
      <div class="bg-white rounded-2xl p-6 max-w-md w-full shadow-2xl transform transition-all">
        <h3 class="text-2xl font-bold mb-4">Share this product</h3>
        
        <div class="space-y-3 mb-6">
          <button class="w-full btn-secondary py-3 flex items-center justify-center gap-3" 
                  onclick="window.open('https://twitter.com/intent/tweet?url=${encodeURIComponent(data.url)}&text=${encodeURIComponent(data.text)}', '_blank')">
            <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
              <path d="M23 3a10.9 10.9 0 01-3.14 1.53 4.48 4.48 0 00-7.86 3v1A10.66 10.66 0 013 4s-4 9 5 13a11.64 11.64 0 01-7 2c9 5 20 0 20-11.5a4.5 4.5 0 00-.08-.83A7.72 7.72 0 0023 3z"></path>
            </svg>
            Share on Twitter
          </button>
          
          <button class="w-full btn-secondary py-3 flex items-center justify-center gap-3"
                  onclick="window.open('https://www.facebook.com/sharer/sharer.php?u=${encodeURIComponent(data.url)}', '_blank')">
            <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
              <path d="M18 2h-3a5 5 0 00-5 5v3H7v4h3v8h4v-8h3l1-4h-4V7a1 1 0 011-1h3z"></path>
            </svg>
            Share on Facebook
          </button>
          
          <div class="flex gap-2">
            <input type="text" 
                   value="${data.url}" 
                   readonly 
                   class="flex-1 input-modern text-sm"
                   id="shareUrl">
            <button class="btn-primary px-4" onclick="
              document.getElementById('shareUrl').select();
              document.execCommand('copy');
              this.textContent = 'Copied!';
              setTimeout(() => this.textContent = 'Copy', 2000);
            ">Copy</button>
          </div>
        </div>
        
        <button class="w-full btn-ghost" onclick="this.closest('.fixed').remove()">
          Close
        </button>
      </div>
    `
    
    document.body.appendChild(modal)
    
    // Close on backdrop click
    modal.addEventListener('click', (e) => {
      if (e.target === modal) {
        modal.remove()
      }
    })
  }
}