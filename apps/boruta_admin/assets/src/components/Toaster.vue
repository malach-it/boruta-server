<template>
  <div @mouseover="activate()" @mouseleave="deactivate()" class="ui icon hidden floating message" :class="type" ref="success">
    <i class="exclamation circle icon"></i>
    <div class="header">
      {{ message }}
    </div>
  </div>
</template>

<script>
export default {
  name: 'success-toaster',
  props: ['active', 'message', 'type'],
  data () {
    return {
      timer: null
    }
  },
  methods: {
    activate() {
      clearTimeout(this.timer)
    },
    deactivate() {
      this.$refs.success.classList.add('hidden')
    }
  },
  watch: {
    active(active) {
      if (!active) return

      this.$refs.success.classList.remove('hidden')

      clearTimeout(this.timer)
      this.timer = setTimeout(() => {
        this.$refs.success.classList.add('hidden')
      }, 5000)
    }
  }
}
</script>

<style scoped lang="scss">
.ui.message {
  transition: transform .3s ease-in-out;
  position: fixed;
  width: auto;
  z-index: 1000;
  top: 4em;
  right: 1em;
  cursor: pointer;
  &.hidden {
    display: flex!important;
    transform: translateX(200%);
  }
}
</style>
