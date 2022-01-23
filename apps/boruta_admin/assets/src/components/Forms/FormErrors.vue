<template>
  <div class="form-errors ui error message">
    <ul>
      <li v-for="key in Object.keys(errors)" :key="key">
        <strong>{{ label(key) }} :</strong> {{ errors[key][0] }}
      </li>
    </ul>
  </div>
</template>

<script>
const labels = {
  'client_relying_parties': 'Client'
}
export default {
  name: 'FormErrors',
  props: ['errors'],
  methods: {
    label(key) {
      return labels[key] || key
    }
  }
}
</script>

<style scoped lang="scss">
</style>
