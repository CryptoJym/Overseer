module.exports = {
  getInput: () => '',
  setSecret: () => {},
  info: () => {},
  warning: () => {},
  setFailed: msg => { throw new Error(msg); }
};
