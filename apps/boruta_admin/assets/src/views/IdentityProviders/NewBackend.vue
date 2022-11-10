<template>
  <div class="new-backend">
    <BackendForm :backend="backend" @submit="createBackend()" @back="back()" action="Create" />
  </div>
</template>

<script>
import Backend from '../../models/backend.model'
import BackendForm from '../../components/Forms/BackendForm.vue'
import Toaster from '../../components/Toaster.vue'

export default {
  name: 'new-backend',
  components: {
    BackendForm,
    Toaster
  },
  data () {
    return {
      backend: new Backend(),
    }
  },
  methods: {
    back () {
      this.$router.push({ name: 'backend-list' })
    },
    createBackend () {
      return this.backend.save().then(({ id }) => {
        this.$router.push({ name: 'edit-backend', params: { backendId: id } })
      }).catch()
    }
  }
}
</script>
