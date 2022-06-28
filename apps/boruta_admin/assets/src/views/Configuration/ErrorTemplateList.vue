<template>
  <div class="error-template-list">
    <div class="container">
      <div class="ui info message">
        Here you can edit error pages user may encounter while navigating through the identity provider.
      </div>
      <div class="ui three column clients stackable grid">
        <div v-for="template in templates" class="ui column" :key="template.type">
          <div class="ui highlitable placeholder segment">
            <div class="ui icon header">
              <i class="object group icon"></i>
              {{ template.label }}
            </div>
            <router-link :to="{ name: `edit-${template.name}-template` }" class="ui primary button">Edit template</router-link>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import ErrorTemplate from '../../models/error-template.model.js'

export default {
  name: 'error-template-list',
  data () {
    return {
      templates: ErrorTemplate.all()
    }
  }
}
</script>
