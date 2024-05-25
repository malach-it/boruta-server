<template>
  <div class="ui organization-form segment">
    <FormErrors :errors="organization.errors" v-if="organization.errors" />
    <form class="ui form" @submit.prevent="submit">
      <h2>General configuration</h2>
      <div class="field">
        <label>Name</label>
        <input type="text" v-model="organization.name" placeholder="wonder-organization" />
      </div>
      <div class="field">
        <label>Label</label>
        <input type="text" v-model="organization.label" placeholder="Wonder organization" />
      </div>
      <div class="actions">
        <button class="ui violet button" type="submit">{{ action }}</button>
      </div>
    </form>
  </div>
</template>

<script>
import FormErrors from './FormErrors.vue'

export default {
  name: 'organization-form',
  props: ['organization', 'action'],
  components: {
    FormErrors
  }
}
</script>
