<template>
  <div class="organization-form">
    <div class="ui segment">
      <FormErrors :errors="organization.errors" v-if="organization.errors" />
      <form class="ui form" @submit.prevent="submit">
        <div class="field">
          <label>Name</label>
          <input type="text" v-model="organization.name" placeholder="Wonder organization" />
        </div>
        <hr />
        <button class="ui right floated violet button" type="submit">{{ action }}</button>
        <a v-on:click="back()" class="ui button">Back</a>
      </form>
    </div>
  </div>
</template>

<script>
import FormErrors from './FormErrors.vue'

export default {
  name: 'organization-form',
  props: ['organization', 'action'],
  components: {
    FormErrors
  },
  methods: {
    back () {
      this.$emit('back')
    }
  }
}
</script>
