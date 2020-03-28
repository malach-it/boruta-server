<template>
  <div class="form-errors ui error message">
    <ul>
      <li v-for="key in Object.keys(errors)" :key="key">
        <strong>{{ key }} :</strong> {{ errors[key][0] }}
      </li>
    </ul>
  </div>
</template>

<script>
export default {
  name: 'FormErrors',
  props: ['errors']
}
</script>

<style scoped lang="scss">
</style>
