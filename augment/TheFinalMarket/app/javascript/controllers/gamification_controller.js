import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "points", "coins", "level", "progressBar", 
    "achievementList", "challengeList", "leaderboard",
    "confetti", "levelUpModal", "achievementModal"
  ]
  
  static values = {
    userId: Number,
    currentPoints: Number,
    currentCoins: Number,
    currentLevel: Number,
    nextLevelPoints: Number
  }

  connect() {
    this.setupWebSocket()
    this.updateProgressBar()
    this.loadDailyChallenges()
    this.checkForNewAchievements()
  }

  disconnect() {
    if (this.subscription) {
      this.subscription.unsubscribe()
    }
  }

  setupWebSocket() {
    // Subscribe to gamification channel for real-time updates
    this.subscription = this.application.consumer.subscriptions.create(
      { channel: "GamificationChannel", user_id: this.userIdValue },
      {
        received: (data) => this.handleUpdate(data)
      }
    )
  }

  handleUpdate(data) {
    switch(data.type) {
      case 'points_awarded':
        this.animatePointsIncrease(data.amount)
        break
      case 'coins_awarded':
        this.animateCoinsIncrease(data.amount)
        break
      case 'level_up':
        this.showLevelUpAnimation(data.new_level)
        break
      case 'achievement_unlocked':
        this.showAchievementUnlocked(data.achievement)
        break
      case 'challenge_completed':
        this.showChallengeCompleted(data.challenge)
        break
    }
  }

  animatePointsIncrease(amount) {
    const currentPoints = this.currentPointsValue
    const newPoints = currentPoints + amount
    
    // Animate counter
    this.animateCounter(this.pointsTarget, currentPoints, newPoints, 1000)
    
    // Show floating points
    this.showFloatingPoints(amount)
    
    // Update progress bar
    this.currentPointsValue = newPoints
    this.updateProgressBar()
    
    // Play sound effect
    this.playSound('points')
  }

  animateCoinsIncrease(amount) {
    const currentCoins = this.currentCoinsValue
    const newCoins = currentCoins + amount
    
    this.animateCounter(this.coinsTarget, currentCoins, newCoins, 1000)
    this.showFloatingCoins(amount)
    this.currentCoinsValue = newCoins
    this.playSound('coins')
  }

  animateCounter(element, start, end, duration) {
    const range = end - start
    const increment = range / (duration / 16) // 60fps
    let current = start
    
    const timer = setInterval(() => {
      current += increment
      if ((increment > 0 && current >= end) || (increment < 0 && current <= end)) {
        current = end
        clearInterval(timer)
      }
      element.textContent = Math.floor(current).toLocaleString()
    }, 16)
  }

  showFloatingPoints(amount) {
    const floater = document.createElement('div')
    floater.className = 'floating-points'
    floater.textContent = `+${amount} points`
    floater.style.cssText = `
      position: fixed;
      top: 50%;
      left: 50%;
      transform: translate(-50%, -50%);
      font-size: 2rem;
      font-weight: bold;
      color: #10b981;
      animation: floatUp 2s ease-out forwards;
      pointer-events: none;
      z-index: 9999;
    `
    
    document.body.appendChild(floater)
    setTimeout(() => floater.remove(), 2000)
  }

  showFloatingCoins(amount) {
    const floater = document.createElement('div')
    floater.className = 'floating-coins'
    floater.innerHTML = `
      <span style="font-size: 2rem;">🪙</span>
      <span style="font-size: 1.5rem; font-weight: bold; color: #f59e0b;">+${amount}</span>
    `
    floater.style.cssText = `
      position: fixed;
      top: 50%;
      left: 50%;
      transform: translate(-50%, -50%);
      display: flex;
      align-items: center;
      gap: 0.5rem;
      animation: floatUp 2s ease-out forwards;
      pointer-events: none;
      z-index: 9999;
    `
    
    document.body.appendChild(floater)
    setTimeout(() => floater.remove(), 2000)
  }

  showLevelUpAnimation(newLevel) {
    // Trigger confetti
    this.triggerConfetti()
    
    // Show level up modal
    if (this.hasLevelUpModalTarget) {
      this.levelUpModalTarget.querySelector('.new-level').textContent = newLevel
      this.levelUpModalTarget.classList.remove('hidden')
      this.levelUpModalTarget.classList.add('animate-bounce')
    }
    
    // Play level up sound
    this.playSound('levelup')
    
    // Update level display
    this.currentLevelValue = newLevel
    if (this.hasLevelTarget) {
      this.levelTarget.textContent = newLevel
    }
    
    // Auto-close modal after 5 seconds
    setTimeout(() => {
      if (this.hasLevelUpModalTarget) {
        this.levelUpModalTarget.classList.add('hidden')
      }
    }, 5000)
  }

  showAchievementUnlocked(achievement) {
    // Trigger confetti
    this.triggerConfetti()
    
    // Show achievement modal
    if (this.hasAchievementModalTarget) {
      this.achievementModalTarget.querySelector('.achievement-name').textContent = achievement.name
      this.achievementModalTarget.querySelector('.achievement-description').textContent = achievement.description
      this.achievementModalTarget.querySelector('.achievement-icon').src = achievement.icon_url
      this.achievementModalTarget.classList.remove('hidden')
    }
    
    // Play achievement sound
    this.playSound('achievement')
    
    // Add to achievement list
    this.prependAchievement(achievement)
    
    // Auto-close after 5 seconds
    setTimeout(() => {
      if (this.hasAchievementModalTarget) {
        this.achievementModalTarget.classList.add('hidden')
      }
    }, 5000)
  }

  showChallengeCompleted(challenge) {
    // Update challenge in list
    const challengeElement = document.querySelector(`[data-challenge-id="${challenge.id}"]`)
    if (challengeElement) {
      challengeElement.classList.add('completed')
      challengeElement.querySelector('.progress-bar').style.width = '100%'
      challengeElement.querySelector('.status').textContent = 'Completed!'
    }
    
    // Show completion animation
    this.showFloatingPoints(challenge.reward_points)
    if (challenge.reward_coins > 0) {
      this.showFloatingCoins(challenge.reward_coins)
    }
    
    this.playSound('challenge')
  }

  updateProgressBar() {
    if (!this.hasProgressBarTarget) return
    
    const progress = (this.currentPointsValue / this.nextLevelPointsValue) * 100
    this.progressBarTarget.style.width = `${Math.min(progress, 100)}%`
    
    // Update tooltip
    const remaining = this.nextLevelPointsValue - this.currentPointsValue
    this.progressBarTarget.setAttribute('title', `${remaining} points to next level`)
  }

  triggerConfetti() {
    if (!this.hasConfettiTarget) return
    
    // Use canvas-confetti library if available
    if (typeof confetti !== 'undefined') {
      confetti({
        particleCount: 100,
        spread: 70,
        origin: { y: 0.6 }
      })
    } else {
      // Fallback CSS animation
      this.confettiTarget.classList.remove('hidden')
      this.confettiTarget.classList.add('animate-confetti')
      
      setTimeout(() => {
        this.confettiTarget.classList.add('hidden')
        this.confettiTarget.classList.remove('animate-confetti')
      }, 3000)
    }
  }

  playSound(type) {
    const sounds = {
      points: '/sounds/points.mp3',
      coins: '/sounds/coins.mp3',
      levelup: '/sounds/levelup.mp3',
      achievement: '/sounds/achievement.mp3',
      challenge: '/sounds/challenge.mp3'
    }
    
    const audio = new Audio(sounds[type])
    audio.volume = 0.3
    audio.play().catch(() => {
      // Ignore if autoplay is blocked
    })
  }

  async loadDailyChallenges() {
    if (!this.hasChallengeListTarget) return
    
    try {
      const response = await fetch('/api/daily_challenges')
      if (response.ok) {
        const html = await response.text()
        this.challengeListTarget.innerHTML = html
      }
    } catch (error) {
      console.error('Failed to load daily challenges:', error)
    }
  }

  async checkForNewAchievements() {
    try {
      const response = await fetch('/api/achievements/check')
      if (response.ok) {
        const data = await response.json()
        if (data.new_achievements && data.new_achievements.length > 0) {
          data.new_achievements.forEach(achievement => {
            this.showAchievementUnlocked(achievement)
          })
        }
      }
    } catch (error) {
      console.error('Failed to check achievements:', error)
    }
  }

  prependAchievement(achievement) {
    if (!this.hasAchievementListTarget) return
    
    const achievementHTML = `
      <div class="achievement-card" data-achievement-id="${achievement.id}">
        <img src="${achievement.icon_url}" alt="${achievement.name}" class="achievement-icon">
        <div class="achievement-info">
          <h4>${achievement.name}</h4>
          <p>${achievement.description}</p>
          <span class="achievement-tier ${achievement.tier}">${achievement.tier}</span>
        </div>
      </div>
    `
    
    this.achievementListTarget.insertAdjacentHTML('afterbegin', achievementHTML)
  }

  closeLevelUpModal() {
    if (this.hasLevelUpModalTarget) {
      this.levelUpModalTarget.classList.add('hidden')
    }
  }

  closeAchievementModal() {
    if (this.hasAchievementModalTarget) {
      this.achievementModalTarget.classList.add('hidden')
    }
  }
}

