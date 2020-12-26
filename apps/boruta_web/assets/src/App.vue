<template>
  <router-view/>
</template>

<script>
export default {
  name: 'App'
}
</script>

<style lang="scss">
#main {
  position: relative;
  h1 {
    text-align: center;
    padding: 1em 0;
    margin: 0;
  }
  a {
    cursor: pointer;
  }
  .actions {
    float: right;
    &.main {
      margin: 1em 0;
    }
  }
  .ui.container {
    width: auto;
    margin-left: 18%!important;
    margin-right: auto!important;
    @media (max-width: 1780px) {
      margin-left: auto!important;
      margin-right: auto!important;
    }
  }
  .ui.input.error>input {
    background-color: #fff6f6;
    border-color: #e0b4b4;
    color: #9f3a38;
    box-shadow: none;
  }
  @media screen and (max-width: 1780px) {
    .rail {
      position: relative;
      width: 60%;
      margin: auto;
      padding: 0;
    }
    .menu {
      text-align: center;
      border-right: none;
      .item {
        border-right: 1px solid #d4d4d5;
        border-left: 1px solid #d4d4d5;
        border-bottom: 1px solid #d4d4d5;
        &.active {
          background: #d4d4d5;
        }
        &:nth-child(1) {
          display: none;
        }
      }
    }
  }
}
</style>
