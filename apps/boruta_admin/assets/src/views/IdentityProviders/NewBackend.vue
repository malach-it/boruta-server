<template>
  <div class="new-backend">
    <Toaster :active="success" message="Backend has been created" type="success" />
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
      success: false
    }
  },
  methods: {
    back () {
      this.$router.push({ name: 'backend-list' })
    },
    createBackend () {
      this.success = false
      return this.backend.save().then(() => {
        this.success = true
        // this.$router.push({ name: 'edit-backend', params: { backendId: this.backend.id } })
        this.$router.push({ name: 'backend-list' })
      }).catch()
    }
  }
}
</script>
