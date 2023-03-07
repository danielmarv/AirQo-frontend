import React from 'react';

const HeaderNav = ({ component, children }) => {
  return (
    <div className='flex justify-between items-center px-6 py-8'>
      <div>
        <span className='text-xl opacity-50 mr-4'>Collocation</span>
        <span className='font-mono opacity-10 text-xl mr-4'>{'>'}</span>
        <span className='text-xl font-semibold'>{component}</span>
      </div>
      <div>{children}</div>
    </div>
  );
};

export default HeaderNav;
