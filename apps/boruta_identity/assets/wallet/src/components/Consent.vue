<template>
  <div class="consent" v-if="eventKey">
    <div class="ui center aligned segment">
      <h2>{{ message }}</h2>
      <div class="ui fluid two buttons">
        <button class="ui orange button" @click="$emit('abort', type)">Abort</button>
        <button class="ui green button" @click="$emit('consent', eventKey)">Proceed</button>
      </div>
    </div>
  </div>
</template>

<script lang="ts">
import { defineComponent } from 'vue';

export default defineComponent({
  name: 'Consent',
  props: {
    eventKey: String,
    message: String,
    type: String
  },
});
</script>

<style lang="scss">
.consent {
  position: fixed;
  z-index: 1000;
  top: 0;
  right: 0;
  bottom: 0;
  left: 0;
  background: rgba(0, 0, 0, 0.7);
  display: flex;
  align-items: center;
  justify-content: center;
}
</style>

