export const getCSRFToken = () => {
  const meta = document.querySelector("meta[name='csrf-token']");

  if (meta) {
    return meta.getAttribute("content");
  }
};
