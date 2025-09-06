<template>
  <div class="feedback">
    <div @click="toggle()" class="ui yellow feedback button">Feedback</div>
    <div class="feedback overlay" v-if="show">
      <div class="ui feedback wrapper massive center aligned segment">
        <i class="ui white close icon" @click="toggle()"></i>
        <h2>Your feedback has value</h2>
        <div class="rating">
          <a v-for="rating in ratings" @click="setRating(rating)">
            <span class="star" v-if="isRatingActive(rating)">&#9733;</span>
            <span class="star" v-if="!isRatingActive(rating)">&#9734;</span>
          </a>
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
    font-size: 2rem;
    height: 2.4rem;
    display: flex;
    align-items: center;
    justify-content: center;

    .star {
      display: block;
      width: 2.4rem;
      cursor: pointer;
      font-weight: bold;
      font-size: 1em;
      color: #fbbd08!important;
      &:hover {
        font-size: 1.4em;
        transition: all .2s ease-in-out;
      }
    }
  }
}
</style>
