export const getCSRFToken = () => {
  return document
    .querySelector("meta[name='csrf-token']")
    ?.getAttribute("content");
};
