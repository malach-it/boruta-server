<template>
  <div class="feedback">
    <div @click="toggle()" class="ui yellow feedback button">Feedback</div>
    <div class="feedback overlay" v-if="show">
      <div class="ui feedback wrapper massive center aligned segment">
        <i class="ui white close icon" @click="toggle()"></i>
        <h2>Your feedback has value</h2>
        <div class="rating">
          <i class="ui large yellow star icon" v-for="rating in ratings" :class="{'outline': !isRatingActive(rating) }" @click="setRating(rating)"></i>
        </div>
        <form target="_blank" class="ui large form" action="https://gateway.boruta.patatoid.fr/store" method="POST">
          <input type="hidden" name="rating" :value="rating" />
          <div class="field">
            <textarea name="feedback" v-model="feedback" placeholder="Say something (optional)" />
          </div>
          <div class="field">
            <div class="ui checkbox">
              <input name="_privacy_policy" type="checkbox" v-model="privacy">
              <label>I have read the <a href="https://io.malach.it/privacy-policy.html" target="_blank"> Privacy policy</a></label>
            </div>
          </div>
          <button :disabled="!privacy" class="ui fluid violet button" type="submit">Submit</button>
        </form>
      </div>
    </div>
  </div>
</template>

<script>
import oauth from '../services/oauth.service'

export default {
  data () {
    const ratings = ['horrible', 'poor', 'neutral', 'good', 'excellent']
    return {
      show: false,
      ratings,
      rating: null,
      feedback: null,
      privacy: false
    }
  },
  computed: {
    isRatingActive () {
      return (rating) => {
        return this.ratings.indexOf(rating) <= this.ratings.indexOf(this.rating)
      }
    }
  },
  methods: {
    toggle () {
      this.show = !this.show
    },
    setRating (rating) {
      this.rating = rating
    }
  }
}
</script>

<style scoped lang="scss">
.feedback.button {
  position: absolute;
  right: 9em;
  top: .5em;
}
.feedback.overlay {
  position: fixed;
  right: 1rem;
  bottom: calc(40px + 1rem);
  z-index: 1000;
}
.feedback.wrapper {
  position: relative;
  .close {
    position: absolute;
    top: -1.2em;
    right: 0;
    cursor: pointer;
  }
  .rating {
    margin-bottom: 1em;
    .star {
      cursor: pointer;
      &:hover {
        transform: scale(120%);
        transition: all .2s ease-in-out;
      }
    }
  }
}
</style>
